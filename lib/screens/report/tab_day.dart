import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../common/constants.dart';
import '../../services/report_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../common/constants.dart';

class DayTab extends StatefulWidget {
  final DateTime selectedDate;
  const DayTab({super.key, required this.selectedDate});

  @override
  State<DayTab> createState() => _DayTabState();
}

class _DayTabState extends State<DayTab> with AutomaticKeepAliveClientMixin {
  // 1. 동적 데이터 및 컨트롤러
  Map<String, Map<String, TextEditingController>> _staffCtrls = {}; // {오전: {사장: ctrl}}
  Map<String, TextEditingController> _menuCtrls = {};
  List<String> _staffRoles = [];
  List<Map<String, dynamic>> _morningMenus = [];

  final _reservationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final Map<String, List<Map<String, dynamic>>> _expiryData = {};

  bool _isConfigLoading = true;
  bool _isLocked = false;
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initDayConfig();
  }

  @override
  void didUpdateWidget(DayTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      _loadDataFromDB(widget.selectedDate);
    }
  }

  // 🚀 1. 입력된 전체 내용을 하나의 텍스트로 합치는 함수
  String _generateSummaryText() {
    final String dateStr = DateFormat('yyyy년 MM월 dd일 (E)').format(widget.selectedDate);
    StringBuffer buffer = StringBuffer();

    buffer.writeln("오전 보고 - $dateStr");
    buffer.writeln("-----------------------------");

    // 인원 현황
    buffer.writeln("근무 인원 현황");
    _staffCtrls.forEach((time, roles) {
      List<String> roleSum = [];
      roles.forEach((role, ctrl) {
        if (ctrl.text != '0' && ctrl.text.isNotEmpty) {
          roleSum.add("$role:${ctrl.text}명");
        }
      });
      if (roleSum.isNotEmpty) buffer.writeln("• $time: ${roleSum.join(', ')}");
    });

    // 메뉴 준비량
    buffer.writeln("\n 메뉴 준비/재고");
    _menuCtrls.forEach((menu, ctrl) {
      if (ctrl.text != '0' && ctrl.text.isNotEmpty) {
        buffer.writeln("• $menu: ${ctrl.text}개");
      }
    });

    // 유통기한 로그
    if (_expiryData.values.any((list) => list.isNotEmpty)) {
      buffer.writeln("\n 유통기한 관리");
      _expiryData.forEach((menu, items) {
        for (var item in items) {
          buffer.writeln("• $menu: ${item['date']} (${item['qty'].toInt()}개)");
        }
      });
    }

    // 예약 및 특이사항
    if (_reservationCtrl.text.isNotEmpty) buffer.writeln("\n 예약: ${_reservationCtrl.text}");
    if (_notesCtrl.text.isNotEmpty) buffer.writeln("\n 특이사항: ${_notesCtrl.text}");

    return buffer.toString();
  }

// 🚀 2. 클립보드 복사 함수
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("리포트가 복사되었습니다."), duration: Duration(seconds: 2)),
      );
    });
  }

  // 🚀 [핵심] 매장 설정 로드 및 동적 컨트롤러 생성
  Future<void> _initDayConfig() async {
    final String currentStoreId = FirebaseAuth.instance.currentUser!.uid;
    try {
      Map<String, dynamic>? config = await ReportService().getStoreConfig(currentStoreId);
      config ??= kDefaultStoreConfig;

      if (mounted) {
        setState(() {
          // 🚀 직책 리스트가 없을 경우 constants.dart의 기본값 사용
          _staffRoles = (config!['dayStaff'] as List?)?.map((e) => e.toString()).toList()
              ?? List<String>.from(kDefaultStoreConfig['dayStaff']!);

          _morningMenus = (config['morningMenu'] as List?)?.map((item) => Map<String, dynamic>.from(item)).toList()
              ?? List<Map<String, dynamic>>.from(kDefaultStoreConfig['morningMenu']!);

          // 근무 시간대별 컨트롤러 생성
          for (var time in ['오전', '오후', '야간']) {
            _staffCtrls[time] = {};
            for (var role in _staffRoles) {
              // 🚀 야간일 경우 '사장'이라는 명칭을 '야간실장'으로 바꿔서 등록합니다.
              String actualRole = (time == '야간' && role == '사장') ? '야간실장' : role;

              String defaultVal = (actualRole == '사장' || actualRole == '정육' || actualRole == '야간실장') ? '1' : '0';
              _staffCtrls[time]![actualRole] = TextEditingController(text: defaultVal);
            }
          }

          // 메뉴 컨트롤러 생성
          for (var menu in _morningMenus) {
            String menuName = menu['name'];
            _menuCtrls[menuName] = TextEditingController(text: '0');
            if (menu['hasExpiry'] == true) {
              _expiryData[menuName] = [];
            }
          }
          _isConfigLoading = false;
        });
        _loadDataFromDB(widget.selectedDate);
      }
    } catch (e) {
      print("Day Config 로드 실패: $e");
      if (mounted) setState(() => _isConfigLoading = false);
    }
  }

  // 🚀 DB에서 데이터 불러오기
  Future<void> _loadDataFromDB(DateTime date) async {
    final String currentStoreId = FirebaseAuth.instance.currentUser!.uid;
    try {
      final report = await ReportService().getReport(date, currentStoreId);
      if (mounted) {
        setState(() {
          if (report == null) {
            _isLocked = false;
            return;
          }
          _isLocked = (report.status == 'complete');

          // 인원 바인딩
          final staff = report.staffCounts ?? {};
          _staffCtrls.forEach((time, roles) {
            roles.forEach((role, ctrl) {
              var val = staff[time]?[role];

              // 🚀 만약 '야간실장' 데이터를 찾는데 없으면, 예전 데이터인 '사장'에서 찾아봅니다.
              if (val == null && time == '야간' && role == '야간실장') {
                val = staff[time]?['사장'];
              }

              ctrl.text = val?.toString() ?? '0';
            });
          });

          // 기타 정보
          _reservationCtrl.text = report.reservation ?? '';
          _notesCtrl.text = report.morningNote ?? '';

          // 메뉴 준비량
          final morningPrep = report.morningPrep ?? {};
          morningPrep.forEach((menu, qty) {
            if (_menuCtrls.containsKey(menu)) _menuCtrls[menu]!.text = qty.toString();
          });

          // 유통기한 로그
          _expiryData.values.forEach((list) => list.clear());
          final expiryLog = report.expiryLog ?? [];
          for (var log in expiryLog) {
            String menuName = log['item'];
            if (_expiryData.containsKey(menuName)) {
              double qty = double.tryParse(log['note'].toString().replaceAll('개', '')) ?? 0.0;
              if (qty > 0) {
                _expiryData[menuName]!.add({'date': log['date'], 'qty': qty});
              }
            }
          }
        });
      }
    } catch (e) {
      print("DayTab 데이터 로드 실패: $e");
    }
  }

  void _clearAllControllers() {
    // 1. 인원 현황 초기화 (특정 직책은 기본값 1 설정)
    _staffCtrls.forEach((time, roles) {
      roles.forEach((role, ctrl) {
        // 사장, 정육, 야간실장은 기본적으로 1명으로 세팅
        if (role == '사장' || role == '정육' || role == '야간실장') {
          ctrl.text = '0';
        } else {
          ctrl.text = '0';
        }
      });
    });

    // 2. 나머지 입력란 초기화
    _menuCtrls.values.forEach((c) => c.text='0');
    _reservationCtrl.clear();
    _notesCtrl.clear();
    _expiryData.values.forEach((list) => list.clear());
  }

  // 🚀 DB 저장
  Future<void> _saveData() async {
    final String dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    int pInt(TextEditingController c) => int.tryParse(c.text.replaceAll(',', '')) ?? 0;
    double pDouble(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '')) ?? 0.0;

    final staffCounts = _staffCtrls.map((time, roles) =>
        MapEntry(time, roles.map((role, ctrl) => MapEntry(role, pInt(ctrl))))
    );

    final Map<String, double> morningPrep = {};
    _menuCtrls.forEach((key, ctrl) {
      double val = pDouble(ctrl);
      if (val > 0) morningPrep[key] = val;
    });

    final List<Map<String, dynamic>> expiryLog = [];
    _expiryData.forEach((menu, items) {
      for (var item in items) {
        expiryLog.add({'item': menu, 'date': item['date'], 'note': '${item['qty']}개'});
      }
    });

    await ReportService().saveMorningReport(
      date: dateStr,
      storeId: FirebaseAuth.instance.currentUser!.uid,
      staffCounts: staffCounts,
      reservation: _reservationCtrl.text,
      morningNote: _notesCtrl.text,
      morningPrep: morningPrep,
      expiryLog: expiryLog,
    );
  }

  // --- UI 빌더 ---

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (ReportService.forceRefresh) {
      // 화면을 그리는 도중에 다시 그리라고 하면 에러가 나므로, 프레임이 끝난 직후 실행합니다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ReportService.forceRefresh = false; // 깃발을 내립니다.
          _loadDataFromDB(widget.selectedDate); // 데이터를 다시 불러와 잠금 상태를 업데이트합니다.
        }
      });
    }

    if (_isConfigLoading) return const Center(child: CircularProgressIndicator(color: khakiMain));

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('근무 인원 현황', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: khakiMain)),
            const SizedBox(height: 15),
            _buildWorkSection('오전 근무', khakiLight, _staffCtrls['오전']!),
            _buildWorkSection('오후 근무', khakiLight, _staffCtrls['오후']!),
            _buildWorkSection('야간 근무', khakiLight, _staffCtrls['야간']!),

            const Divider(height: 40),
            const Text('메뉴별 준비/재고', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: khakiMain)),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.3, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: _morningMenus.length,
              itemBuilder: (context, index) {
                final menu = _morningMenus[index];
                return _buildCounterField(
                    label: menu['name'],
                    controller: _menuCtrls[menu['name']]!,
                    hasExpiry: menu['hasExpiry'] ?? false
                );
              },
            ),

            const Divider(height: 40),
            _buildExtraSection(),
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed: _isLocked ? null : _showCheckDialog, icon: const Icon(Icons.save_alt), label: const Text('오전 내용 저장'), style: ElevatedButton.styleFrom(backgroundColor: khakiLight, foregroundColor: Colors.white))),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkSection(String title, Color color, Map<String, TextEditingController> roles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: roles.entries.map((e) => SizedBox(
            width: (MediaQuery.of(context).size.width / 2) - 22,
            child: _buildCounterField(label: e.key, controller: e.value, isInteger: true),
          )).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCounterField({required String label, required TextEditingController controller, bool isInteger = false, bool hasExpiry = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (hasExpiry) Padding(padding: const EdgeInsets.only(left: 4), child: GestureDetector(onTap: () => _showExpiryDialog(label), child: const Icon(Icons.calendar_month, size: 16, color: khakiMain))),
        ]),
        const SizedBox(height: 4),
        Container(
          height: 40,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.remove, size: 14), onPressed: _isLocked ? null : () => _adjustValue(controller, -1)),
              Expanded(
                  child: TextField(
                  readOnly: _isLocked,
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true))),
              IconButton(icon: const Icon(Icons.add, size: 14), onPressed: _isLocked ? null : () => _adjustValue(controller, 1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExtraSection() {
    return Column(
      children: [
        TextField(readOnly: _isLocked, controller: _reservationCtrl, decoration: const InputDecoration(labelText: '예약 현황', border: OutlineInputBorder(), prefixIcon: Icon(Icons.event_note))),
        const SizedBox(height: 15),
        TextField(readOnly: _isLocked, controller: _notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '오전 특이사항', border: OutlineInputBorder(), prefixIcon: Icon(Icons.note))),
      ],
    );
  }

  // --- 기존 헬퍼 및 다이얼로그 로직 유지 ---
  void _adjustValue(TextEditingController ctrl, double amt) {
    double val = (double.tryParse(ctrl.text.replaceAll(',', '')) ?? 0) + amt;
    ctrl.text = val < 0 ? '0' : (val % 1 == 0 ? val.toInt().toString() : val.toString());
  }

  // 🚀 유통기한 리스트의 합계를 메인 화면 컨트롤러에 반영하는 함수
  void _syncExpiryToTotal(String menuName) {
    if (_expiryData.containsKey(menuName) && _menuCtrls.containsKey(menuName)) {
      double total = 0;
      for (var item in _expiryData[menuName]!) {
        total += (double.tryParse(item['qty'].toString()) ?? 0.0);
      }
      // 메인 화면의 해당 메뉴 소수점 여부에 따라 표시 (정수면 정수로)
      _menuCtrls[menuName]!.text = total % 1 == 0 ? total.toInt().toString() : total.toString();
    }
  }

  void _showExpiryDialog(String menuName) {
    DateTime tempDate = DateTime.now();
    final TextEditingController tempQtyCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('$menuName 유통기한 관리',
                  style: const TextStyle(color: khakiMain, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- 1. 신규 입력 영역 (상단) ---
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("입고일:", style: TextStyle(fontWeight: FontWeight.bold)),
                              TextButton.icon(
                                icon: const Icon(Icons.calendar_today, size: 16, color: khakiMain),
                                label: Text(DateFormat('yyyy년 MM월 dd일').format(tempDate)),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: tempDate,
                                    firstDate: DateTime(2004),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => tempDate = picked);
                                  }
                                },
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("수량:", style: TextStyle(fontWeight: FontWeight.bold)),
                              // 🚀 신규 입력 수량 조절 버튼 추가
                              Row(
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                    onPressed: () {
                                      double val = double.tryParse(tempQtyCtrl.text) ?? 0.0;
                                      if (val > 1) setDialogState(() => tempQtyCtrl.text = (val - 1).toInt().toString());
                                    },
                                  ),
                                  SizedBox(
                                    width: 50,
                                    child: TextField(
                                      readOnly: _isLocked,
                                      controller: tempQtyCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textAlign: TextAlign.center,
                                      decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                                    onPressed: () {
                                      double val = double.tryParse(tempQtyCtrl.text) ?? 0.0;
                                      setDialogState(() => tempQtyCtrl.text = (val + 1).toInt().toString());
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: khakiMain),
                              // [1] '목록에 추가' 버튼 눌렀을 때
                              onPressed: _isLocked ? null : () {
                                double qty = double.tryParse(tempQtyCtrl.text) ?? 0.0;
                                if (qty > 0) {
                                  setState(() {
                                    _expiryData[menuName]!.add({
                                      'date': DateFormat('yyyy-MM-dd').format(tempDate),
                                      'qty': qty
                                    });
                                    _syncExpiryToTotal(menuName); // 🚀 추가 후 메인 화면 동기화
                                  });
                                  setDialogState(() {});
                                  tempQtyCtrl.text = '1';
                                }
                              },
                              child: const Text("목록에 추가"),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const Text("유통기한 목록", style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 10),

                    // --- 2. 기존 입력 목록 영역 (하단 ListView) ---
                    Flexible(
                      child: _expiryData[menuName]!.isEmpty
                          ? const Padding(padding: EdgeInsets.all(20.0), child: Text("등록된 항목이 없습니다."))
                          : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _expiryData[menuName]!.length,
                        itemBuilder: (c, idx) {
                          final item = _expiryData[menuName]![idx];
                          return ListTile(
                            visualDensity: VisualDensity.compact,
                            leading: const Icon(Icons.history, size: 18),
                            title: Text("${item['date']}"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 🚀 기존 목록 수량 (-) 버튼
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.remove, size: 18, color: Colors.grey),
                                  onPressed: _isLocked ? null : () {
                                    setState(() {
                                      double currentQty = double.tryParse(item['qty'].toString()) ?? 0.0;
                                      if (currentQty > 1) {
                                        _expiryData[menuName]![idx]['qty'] = currentQty - 1;
                                        _syncExpiryToTotal(menuName); // 🚀 변경 후 메인 화면 동기화
                                      }
                                    });
                                    setDialogState(() {});
                                  },
                                ),
                                Text("${item['qty'].toInt()}개", style: const TextStyle(fontWeight: FontWeight.bold)),
                                // 🚀 기존 목록 수량 (+) 버튼
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.add, size: 18, color: Colors.grey),
                                  onPressed: _isLocked ? null : () {
                                    setState(() {
                                      double currentQty = double.tryParse(item['qty'].toString()) ?? 0.0;
                                      _expiryData[menuName]![idx]['qty'] = currentQty + 1;
                                      _syncExpiryToTotal(menuName); // 🚀 변경 후 메인 화면 동기화
                                    });
                                    setDialogState(() {});
                                  },
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                  onPressed: _isLocked ? null : () {
                                    setState(() {
                                      _expiryData[menuName]!.removeAt(idx);
                                      _syncExpiryToTotal(menuName); // 🚀 삭제 후 메인 화면 동기화
                                    });
                                    setDialogState(() {});
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("닫기", style: TextStyle(color: Colors.grey))),
              ],
            );
          },
        );
      },
    );
  }

  void _showCheckDialog() {
    final String summary = _generateSummaryText();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("보고 내용 확인",
            style: TextStyle(color: khakiMain, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          // 🚀 보고 내용이 길어질 수 있으니 스크롤은 유지하되, 박스(Container)는 제거했습니다.
          child: SingleChildScrollView(
            child: Text(
                summary,
                style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87)
            ),
          ),
        ),
        actions: [
          // 🚀 복사 버튼
          TextButton.icon(
            onPressed: () => _copyToClipboard(summary),
            icon: const Icon(Icons.copy, size: 18),
            label: const Text("복사"),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("취소", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: khakiMain,
                elevation: 0, // 너무 튀지 않게 평평하게 처리
              ),
              onPressed: () async {
                await _saveData();
                Navigator.pop(ctx);
              },
              child: const Text("저장")
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _staffCtrls.forEach((_, roles) => roles.values.forEach((c) => c.dispose()));
    _menuCtrls.values.forEach((c) => c.dispose());
    _reservationCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }
}
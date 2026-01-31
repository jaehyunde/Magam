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
              // 🚀 [핵심 수정] 사장, 정육, 실장 등 주요 직책은 기본값 '1' 설정
              String defaultVal = (role == '사장' || role == '정육' || role == '야간실장') ? '1' : '0';
              _staffCtrls[time]![role] = TextEditingController(text: defaultVal);
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
            _clearAllControllers();
            return;
          }

          // 인원 바인딩
          final staff = report.staffCounts ?? {};
          _staffCtrls.forEach((time, roles) {
            roles.forEach((role, ctrl) {
              ctrl.text = staff[time]?[role]?.toString() ?? '0';
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

  // --- UI 빌더 (디자인 유지) ---

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed: _showCheckDialog, icon: const Icon(Icons.save_alt), label: const Text('오전 내용 저장'), style: ElevatedButton.styleFrom(backgroundColor: khakiLight, foregroundColor: Colors.white))),
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
              IconButton(icon: const Icon(Icons.remove, size: 14), onPressed: () => _adjustValue(controller, -1)),
              Expanded(child: TextField(controller: controller, textAlign: TextAlign.center, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, isDense: true))),
              IconButton(icon: const Icon(Icons.add, size: 14), onPressed: () => _adjustValue(controller, 1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExtraSection() {
    return Column(
      children: [
        TextField(controller: _reservationCtrl, decoration: const InputDecoration(labelText: '예약 현황', border: OutlineInputBorder(), prefixIcon: Icon(Icons.event_note))),
        const SizedBox(height: 15),
        TextField(controller: _notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '오전 특이사항', border: OutlineInputBorder(), prefixIcon: Icon(Icons.note))),
      ],
    );
  }

  // --- 기존 헬퍼 및 다이얼로그 로직 유지 ---
  void _adjustValue(TextEditingController ctrl, double amt) {
    double val = (double.tryParse(ctrl.text.replaceAll(',', '')) ?? 0) + amt;
    ctrl.text = val < 0 ? '0' : (val % 1 == 0 ? val.toInt().toString() : val.toString());
  }

  void _showExpiryDialog(String menuName) {
    // [사용자님의 기존 유통기한 다이얼로그 로직을 그대로 사용하세요]
  }

  void _showCheckDialog() {
    // [사용자님의 기존 확인 다이얼로그 로직을 사용하되, _staffCtrls와 _menuCtrls를 순회하도록 수정]
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("저장 확인"),
        content: const Text("입력한 내용을 저장하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
          ElevatedButton(onPressed: () async { await _saveData(); Navigator.pop(ctx); }, child: const Text("저장"))
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
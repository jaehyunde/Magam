import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../common/constants.dart';
import '../../services/report_service.dart'; // 🚀 [필수] DB 서비스 임포트
import 'package:firebase_auth/firebase_auth.dart';

class ClosingTab extends StatefulWidget {
  // 🚀 상위에서 날짜 받아옴
  final DateTime selectedDate;

  const ClosingTab({super.key, required this.selectedDate});

  @override
  State<ClosingTab> createState() => _ClosingTabState();
}

class _ClosingTabState extends State<ClosingTab> with AutomaticKeepAliveClientMixin {
  // 1. 동적 컨트롤러 관리를 위한 Map
  Map<String, TextEditingController> _salesCtrls = {};    // 매출 관련 (현금성)
  Map<String, TextEditingController> _expenseCtrls = {};  // 지출 관련
  Map<String, Map<String, TextEditingController>> _inventory = {}; // 재고 관련

  // 고정 컨트롤러 (시스템 필수 항목)
  final _cardSalesCtrl = TextEditingController();
  final _weeklySalesCtrl = TextEditingController();
  final _hireCtrl = TextEditingController();
  final _resignCtrl = TextEditingController();
  final _transferCtrl = TextEditingController();
  final _preDepositCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _managerNameCtrl = TextEditingController();

  // 합계 변수
  int _cashTotal = 0;
  int _grandTotal = 0;
  int _expenseTotal = 0;

  bool _isConfigLoading = true;
  bool _isLocked = false; // 🚀 잠금 상태 변수 추가

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initStoreConfig(); // 🚀 1. 설정 먼저 로드
  }
  // 🚀 [추가] 부모 위젯(달력)에서 날짜가 바뀌었을 때 실행되는 코드
  @override
  void didUpdateWidget(covariant ClosingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 💡 선택된 날짜가 실제로 바뀌었는지 확인 후 데이터를 다시 로드합니다.
    if (oldWidget.selectedDate != widget.selectedDate) {
      print("🚩 [ClosingTab] 날짜 변경 감지: ${widget.selectedDate} -> 로드 시작");
      _loadDataFromDB(widget.selectedDate);
    }
  }

  Future<void> _initStoreConfig() async {
    final String currentStoreId = FirebaseAuth.instance.currentUser!.uid;
    try {
      Map<String, dynamic>? config = await ReportService().getStoreConfig(currentStoreId);
      config ??= kDefaultStoreConfig;

      if (mounted) {
        setState(() {
          // 🚀 리스트를 가져올 때 하나씩 toString() 처리하여 Map 데이터가 섞여도 튕기지 않게 함
          final List sList = config!['sales'] ?? [];
          for (var item in sList) {
            _salesCtrls[item.toString()] = TextEditingController()..addListener(_updateSalesTotal);
          }

          final List eList = config['expenses'] ?? [];
          for (var item in eList) {
            _expenseCtrls[item.toString()] = TextEditingController()..addListener(_updateExpenseTotal);
          }

          final List mList = config['menu'] ?? [];
          for (var item in mList) {
            _inventory[item.toString()] = {
              '시작재고': TextEditingController(), '입고': TextEditingController(),
              '판매': TextEditingController(), '포스': TextEditingController(),
              '실재': TextEditingController(), '파지': TextEditingController(),
            };
          }
          _cardSalesCtrl.addListener(_updateSalesTotal);
          _isConfigLoading = false;
        });
        _loadDataFromDB(widget.selectedDate);
      }
    } catch (e) {
      print("Closing Config 로드 실패 상세: $e");
      if (mounted) setState(() => _isConfigLoading = false);
    }
  }

  Future<void> _loadDataFromDB(DateTime date) async {
    final String currentStoreId = FirebaseAuth.instance.currentUser!.uid;
    // 🚀 기존에 임포트된 NumberFormat을 사용하여 포맷팅 준비
    final formatter = NumberFormat('#,###');

    void _clearAllControllers() {
      _salesCtrls.values.forEach((c) => c.clear());
      _expenseCtrls.values.forEach((c) => c.clear());
      _inventory.values.forEach((itemMap) => itemMap.values.forEach((c) => c.clear()));
      _cardSalesCtrl.clear();
      _weeklySalesCtrl.clear();
      _hireCtrl.clear();
      _resignCtrl.clear();
      _transferCtrl.clear();
      _preDepositCtrl.clear();
      _notesCtrl.clear();
      _managerNameCtrl.clear();
      _cashTotal = 0; _grandTotal = 0; _expenseTotal = 0;
    }

    try {
      final report = await ReportService().getReport(date, currentStoreId);

      // 🚩 [디버그 로그] 데이터 수신 확인
      print("🚩 [ClosingTab] 데이터 로드 시도: ${DateFormat('yyyy-MM-dd').format(date)}");
      if (report == null) {
        print("🚩 [ClosingTab] 결과: 해당 날짜의 데이터가 없습니다(null).");
      } else {
        print("🚩 [ClosingTab] 결과: 데이터 발견! (책임자: ${report.author})");
      }

      if (mounted) {
        setState(() {
          if (report == null) {
            _clearAllControllers();
            _isLocked = false; // 데이터 없으면 잠금 해제
            return;
          }

          // 1. 매출 데이터 바인딩 (숫자를 콤마 포맷으로 변환하여 주입)
          final cashFlow = report.cashFlow ?? {};
          _salesCtrls.forEach((key, ctrl) {
            final val = cashFlow[key];
            // 🚀 [보정] raw 숫자를 콤마가 포함된 문자열로 바꿔서 컨트롤러에 넣습니다.
            ctrl.text = (val == null || val == 0) ? '' : formatter.format(val);
            if (val != null) print("🚩 [ClosingTab] 매출 로드: $key = $val");
          });

          _cardSalesCtrl.text = (report.cardSales == null || report.cardSales == 0)
              ? '' : formatter.format(report.cardSales);

          final weekly = cashFlow['주간매출'];
          _weeklySalesCtrl.text = (weekly == null || weekly == 0) ? '' : formatter.format(weekly);

          // 2. 지출 데이터 바인딩
          for (var expense in report.expenseList ?? []) {
            final key = expense['category']?.toString();
            if (key != null && _expenseCtrls.containsKey(key)) {
              final amt = expense['amount'];
              _expenseCtrls[key]!.text = (amt == null || amt == 0) ? '' : formatter.format(amt);
            }
          }

          // 3. 재고 데이터 바인딩 (수량 데이터이므로 기존처럼 유지)
          for (var log in report.inventoryLog ?? []) {
            final item = log['품목명']?.toString();
            if (item != null && _inventory.containsKey(item)) {
              final map = _inventory[item]!;
              map['시작재고']!.text = log['시작재고']?.toString() ?? '';
              map['입고']!.text = log['입고']?.toString() ?? '';
              map['판매']!.text = log['판매']?.toString() ?? '';
              map['포스']!.text = log['포스']?.toString() ?? '';
              map['실재']!.text = log['실재']?.toString() ?? '';
              map['파지']!.text = log['파지']?.toString() ?? '';
            }
          }

          // 4. 인사 및 기타 정보
          _hireCtrl.text = report.hiring ?? '';
          _resignCtrl.text = report.leaving ?? '';
          _transferCtrl.text = report.transfer ?? '';
          _preDepositCtrl.text = report.preDeposit ?? '';
          _notesCtrl.text = report.closingNote ?? '';
          _managerNameCtrl.text = report.author ?? '';

          // 🚀 [필수] 모든 컨트롤러에 데이터 주입 후 합계를 다시 계산하여 화면 갱신
          _updateSalesTotal();
          _updateExpenseTotal();
          _isLocked = (report.status == 'complete');
        });
      }
    } catch (e) {
      print("❌ [ClosingTab] 데이터 로드 중 치명적 에러: $e");
    }
  }

  void _updateSalesTotal() {
    int parse(TextEditingController c) => int.tryParse(c.text.replaceAll(',', '')) ?? 0;

    // 동적 매출 항목 합산
    int totalCash = 0;
    _salesCtrls.values.forEach((c) => totalCash += parse(c));

    int card = parse(_cardSalesCtrl);

    setState(() {
      _cashTotal = totalCash;
      _grandTotal = _cashTotal + card;
    });
  }

  void _updateExpenseTotal() {
    int sum = 0;
    _expenseCtrls.values.forEach((c) => sum += int.tryParse(c.text.replaceAll(',', '')) ?? 0);
    setState(() => _expenseTotal = sum);
  }

  Future<void> _saveToDB() async {
    final String dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    int p(TextEditingController c) => int.tryParse(c.text.replaceAll(',', '')) ?? 0;
    String val(TextEditingController? c) => c?.text.replaceAll(',', '') ?? '0';

    // 1. 매출 데이터 생성
    final Map<String, dynamic> cashFlow = {};
    _salesCtrls.forEach((key, ctrl) => cashFlow[key] = p(ctrl));
    cashFlow['총현금매출'] = _cashTotal;
    cashFlow['주간매출'] = p(_weeklySalesCtrl);

    // 2. 지출 리스트 생성
    final List<Map<String, dynamic>> expenseList = [];
    _expenseCtrls.forEach((key, ctrl) {
      if (p(ctrl) > 0) {
        expenseList.add({'category': key, 'amount': p(ctrl), 'note': '지출'});
      }
    });

    // 3. 재고 리스트 생성
    final List<Map<String, dynamic>> inventoryLog = [];
    _inventory.forEach((itemName, data) {
      inventoryLog.add({
        '품목명': itemName,
        '시작재고': val(data['시작재고']),
        '입고': val(data['입고']),
        '판매': val(data['판매']),
        '포스': val(data['포스']),
        '실재': val(data['실재']),
        '파지': val(data['파지']),
      });
    });

    final String currentStoreId = FirebaseAuth.instance.currentUser!.uid;

    await ReportService().saveClosingReport(
      date: dateStr,
      storeId: currentStoreId,
      author: _managerNameCtrl.text,
      grandTotal: _grandTotal,
      cardSales: p(_cardSalesCtrl),
      cashFlow: cashFlow,
      expenseList: expenseList,
      inventoryLog: inventoryLog,
      closingNote: _notesCtrl.text,
      hiring: _hireCtrl.text,
      leaving: _resignCtrl.text,
      transfer: _transferCtrl.text,
      preDeposit: _preDepositCtrl.text,
      status: 'complete',
    );
  }

  // --- 기존의 다이얼로그 및 UI 헬퍼 위젯들은 그대로 유지 (생략) ---

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isConfigLoading) {
      return const Center(child: CircularProgressIndicator(color: khakiMain));
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('매출 결산', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: khakiMain)),
            const SizedBox(height: 15),

            // 🚀 동적 매출 필드 생성
            ..._salesCtrls.entries.map((e) => _buildMoneyField(e.key, e.value)).toList(),

            _buildReadOnlyField('현금매출 합계', _cashTotal, taupelight),
            _buildMoneyField('카드매출', _cardSalesCtrl),
            _buildReadOnlyField('총 매출', _grandTotal, brownbear),
            _buildMoneyField('주간매출', _weeklySalesCtrl),

            const SizedBox(height: 30),
            const Divider(thickness: 1),
            const Text('지출 내역 상세', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: khakiMain)),
            const SizedBox(height: 15),

            // 🚀 동적 지출 필드 생성 (2열 배치)
            Wrap(
              spacing: 8,
              children: _expenseCtrls.entries.map((e) => SizedBox(
                width: (MediaQuery.of(context).size.width / 2) - 24,
                child: _buildMoneyField(e.key, e.value),
              )).toList(),
            ),
            _buildReadOnlyField('지출 총계', _expenseTotal, dullbrown),

            const SizedBox(height: 30),
            const Divider(thickness: 1),
            const Text('재고 관리', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: khakiMain)),
            const SizedBox(height: 10),

            // 🚀 동적 재고 테이블 생성
            _buildDynamicInventoryTable(),// 🚀 [복구 및 추가 시작]
            const SizedBox(height: 30),
            const Divider(thickness: 1),
            const Text('인사 및 기타 사항', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: khakiMain)),
            const SizedBox(height: 15),

            // 인사 정보 필드 (채용, 퇴사, 전출 등)
            _buildGeneralTextField('입사/채용 내역', _hireCtrl, Icons.person_add),
            _buildGeneralTextField('퇴사 내역', _resignCtrl, Icons.person_remove),
            _buildGeneralTextField('전출/전입/기타', _transferCtrl, Icons.swap_horiz),
            _buildGeneralTextField('선입금', _preDepositCtrl, Icons.account_balance_wallet),

            const SizedBox(height: 20),
            _buildGeneralTextField('마감 특이사항', _notesCtrl, Icons.note_alt, maxLines: 3),

            const SizedBox(height: 30),
            const Divider(thickness: 1),

            // 책임자 이름 입력 (제출 전 필수 확인 항목)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: TextField(
                controller: _managerNameCtrl,
                decoration: const InputDecoration(
                  labelText: '책임자 이름',
                  hintText: '이름을 입력하세요',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.assignment_ind, color: khakiMain),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // 🚀 대망의 저장 및 제출 버튼
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isLocked ? null : _submitReport,
                icon: const Icon(Icons.send_rounded),
                label: const Text('마감 보고서 최종 제출', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: khakiMain,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 3,
                ),
              ),
            ),
            const SizedBox(height: 50), // 하단 여백
          ],
        ),
      ),
    );
  }

  // 🚀 일반 텍스트 입력을 위한 헬퍼 위젯 (추가 필요)
  Widget _buildGeneralTextField(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        readOnly: _isLocked,
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey, size: 20),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  // --- 🚀 사라졌던 UI 헬퍼 위젯들 다시 추가 ---

  // 1. 돈 입력 필드 (매출, 지출용)
  Widget _buildMoneyField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        readOnly: _isLocked,
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
        onTap: () { if (controller.text == '0') controller.text = ''; },
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          hintText: '0',
          suffixText: '원',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          border: const OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade400)),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: khakiMain, width: 2.0)),
          fillColor: Colors.white,
          filled: true,
        ),
      ),
    );
  }

  // 2. 합계 표시용 읽기 전용 필드
  Widget _buildReadOnlyField(String label, int value, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          Text("${NumberFormat('#,###').format(value)}원", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        ],
      ),
    );
  }

  // 3. 재고 테이블의 각 입력 셀
  Widget _buildInventoryCell(TextEditingController ctrl) {
    return Container(
      width: 60,
      margin: const EdgeInsets.all(2),
      child: TextField(
        readOnly: _isLocked,
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          hintText: '0',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  // --- 🚀 제출 관련 로직 함수들 ---

  void _submitReport() {
    if (_managerNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('책임자 이름을 입력해주세요.')));
      return;
    }
    if (_grandTotal == 0) {
      _showZeroSalesWarning();
      return;
    }
    _showConfirmDialog();
  }

  void _showZeroSalesWarning() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ 매출 0원 보고서"),
        content: const Text("총 매출이 0원으로 보고되었습니다. 정상적인 영업일이 맞습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("수정")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showConfirmDialog();
            },
            child: const Text("강제 제출"),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog() {
    final f = NumberFormat('#,###');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("📤 마감 보고서 제출"),
        content: Text("👤 책임자: ${_managerNameCtrl.text}\n💰 총 매출: ${f.format(_grandTotal)}원\n💸 지출 총계: ${f.format(_expenseTotal)}원\n\n정말 제출하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("수정")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: khakiMain, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                // 1. DB에 저장 실행
                await _saveToDB();

                if (mounted) {
                  ReportService.forceRefresh = true;

                  setState(() { _isLocked = true; });
                  Navigator.pop(ctx);

                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 마감 보고서가 저장되었습니다!')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ 저장 실패: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text("제출 및 저장"),
          ),
        ],
      ),
    );
  }

  // 🚀 재고 테이블 동적 생성 헬퍼
  Widget _buildDynamicInventoryTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(70),
        border: TableBorder.all(color: Colors.grey.shade300),
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.grey.shade200),
            children: const [
              Padding(padding: EdgeInsets.all(8), child: Center(child: Text('품명', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
              Center(child: Text('시작', style: TextStyle(fontSize: 11))),
              Center(child: Text('입고', style: TextStyle(fontSize: 11))),
              Center(child: Text('판매', style: TextStyle(fontSize: 11))),
              Center(child: Text('포스', style: TextStyle(fontSize: 11))),
              Center(child: Text('실재', style: TextStyle(fontSize: 11, color: Colors.red))),
              Center(child: Text('파지', style: TextStyle(fontSize: 11))),
            ],
          ),
          ..._inventory.entries.map((entry) {
            return TableRow(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  child: Text(entry.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                _buildInventoryCell(entry.value['시작재고']!),
                _buildInventoryCell(entry.value['입고']!),
                _buildInventoryCell(entry.value['판매']!),
                _buildInventoryCell(entry.value['포스']!),
                _buildInventoryCell(entry.value['실재']!),
                _buildInventoryCell(entry.value['파지']!),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _salesCtrls.values.forEach((c) => c.dispose());
    _expenseCtrls.values.forEach((c) => c.dispose());
    _inventory.values.forEach((m) => m.values.forEach((c) => c.dispose()));
    _cardSalesCtrl.dispose(); _weeklySalesCtrl.dispose();
    _hireCtrl.dispose(); _resignCtrl.dispose(); _transferCtrl.dispose();
    _preDepositCtrl.dispose(); _notesCtrl.dispose(); _managerNameCtrl.dispose();
    super.dispose();
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (newText.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final int value = int.parse(newText);
    final String newString = NumberFormat('#,###').format(value);
    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }
}
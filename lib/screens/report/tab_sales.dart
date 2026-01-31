import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../common/constants.dart';
import '../../services/report_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SalesTab extends StatefulWidget {
  final DateTime selectedDate;
  const SalesTab({super.key, required this.selectedDate});

  @override
  State<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<SalesTab> with AutomaticKeepAliveClientMixin {
  Map<String, Map<String, TextEditingController>> _salesTimeCtrls = {};
  Map<String, Map<String, TextEditingController>> _menuVolumeCtrls = {};

  List<String> _salesTimeKeys = [];
  List<String> _salesCategoryKeys = [];
  List<String> _menuKeys = []; // 🚀 [추가] DB에서 불러온 메뉴 항목들을 담을 변수
  bool _isConfigLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(SalesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      _loadDataFromDB(widget.selectedDate);
    }
  }

  // 🚀 매장 설정 로드 및 컨트롤러 동적 생성
  // lib/screens/report/tab_sales.dart 내 _initSalesConfig 함수

  Future<void> _initSalesConfig() async {
    final String currentStoreId = FirebaseAuth.instance.currentUser!.uid;
    try {
      // 🚀 타입을 dynamic으로 받아 어떤 형태든 수용하게 함
      Map<String, dynamic>? config = await ReportService().getStoreConfig(currentStoreId);
      config ??= kDefaultStoreConfig;

      if (mounted) {
        setState(() {
          // 🚀 [핵심 수정] 리스트 안의 내용물이 무엇이든 .toString()으로 안전하게 변환
          _salesTimeKeys = (config!['salesTime'] as List?)?.map((e) => e.toString()).toList() ?? [];
          _salesCategoryKeys = (config['salesCategory'] as List?)?.map((e) => e.toString()).toList() ?? [];
          _menuKeys = (config['menu'] as List?)?.map((e) => e.toString()).toList() ?? [];

          for (var time in _salesTimeKeys) {
            _salesTimeCtrls[time] = {};
            for (var cat in _salesCategoryKeys) {
              _salesTimeCtrls[time]![cat] = TextEditingController()..addListener(_updateTotal);
            }
            if (time != '점심') {
              _menuVolumeCtrls[time] = {};
              for (var menu in _menuKeys) {
                _menuVolumeCtrls[time]![menu] = TextEditingController();
              }
            }
          }
          _isConfigLoading = false; // 로딩 종료
        });
        _loadDataFromDB(widget.selectedDate);
      }
    } catch (e) {
      print("Sales Config 로드 실패 상세: $e");
      if (mounted) setState(() => _isConfigLoading = false); // 에러 시에도 로딩은 멈춰야 함
    }
  }

  // 🚀 데이터 로드 및 바인딩
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

          final salesTimeData = report.salesTime ?? {};
          _salesTimeCtrls.forEach((time, cats) {
            cats.forEach((cat, ctrl) {
              ctrl.text = salesTimeData[time]?[cat]?.toString() ?? '';
            });
          });

          final dayVol = report.dayVolume ?? {};
          final nightVol = report.nightVolume ?? {};
          _menuVolumeCtrls.forEach((time, menus) {
            final volData = (time == '야간') ? nightVol : dayVol;
            menus.forEach((menu, ctrl) {
              final qty = volData[menu];
              ctrl.text = (qty != null && qty > 0) ? qty.toString() : '';
            });
          });

          _updateTotal();
        });
      }
    } catch (e) {
      print("SalesTab 데이터 로드 실패: $e");
    }
  }

  void _clearAllControllers() {
    _salesTimeCtrls.forEach((_, cats) => cats.values.forEach((c) => c.clear()));
    _menuVolumeCtrls.forEach((_, menus) => menus.values.forEach((c) => c.clear()));
    _lunchTotal = 0; _dayTotal = 0; _nightTotal = 0; _grandTotal = 0;
    _totalRibs = 0; _totalButcher = 0; _totalTogo = 0;
  }

  int _currentTabIndex = 0;
  int _lunchTotal = 0; int _dayTotal = 0; int _nightTotal = 0; int _grandTotal = 0;
  int _totalRibs = 0; int _totalButcher = 0; int _totalTogo = 0;

  @override
  void initState() {
    super.initState();
    _initSalesConfig();
  }

  @override
  void dispose() {
    _salesTimeCtrls.forEach((_, cats) => cats.values.forEach((c) => c.dispose()));
    _menuVolumeCtrls.forEach((_, menus) => menus.values.forEach((c) => c.dispose()));
    super.dispose();
  }

  // 🚀 DB 저장
  Future<void> _saveToDB() async {
    final String dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    int p(TextEditingController c) => int.tryParse(c.text.replaceAll(',', '')) ?? 0;
    double pD(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '')) ?? 0.0;

    final Map<String, Map<String, int>> salesTime = {};
    _salesTimeCtrls.forEach((time, cats) {
      salesTime[time] = cats.map((cat, ctrl) => MapEntry(cat, p(ctrl)));
    });

    final Map<String, double> dayVolume = {};
    final Map<String, double> nightVolume = {};

    // 🚀 [수정] _menuKeys 기반으로 저장 데이터 생성
    _menuVolumeCtrls['주간']?.forEach((menu, ctrl) {
      if (pD(ctrl) > 0) dayVolume[menu] = pD(ctrl);
    });
    _menuVolumeCtrls['야간']?.forEach((menu, ctrl) {
      if (pD(ctrl) > 0) nightVolume[menu] = pD(ctrl);
    });

    final String currentStoreId = FirebaseAuth.instance.currentUser!.uid;

    await ReportService().saveSalesReport(
      date: dateStr,
      storeId: currentStoreId,
      salesTime: salesTime,
      dayVolume: dayVolume,
      nightVolume: nightVolume,
      status: 'writing',
    );
  }

  void _updateTotal() {
    int p(TextEditingController ctrl) => int.tryParse(ctrl.text.replaceAll(',', '')) ?? 0;
    int lSum = 0; int dSum = 0; int nSum = 0;
    int ribs = 0; int butcher = 0; int togo = 0;

    _salesTimeCtrls.forEach((time, cats) {
      int sectionTotal = 0;
      cats.forEach((cat, ctrl) {
        int val = p(ctrl);
        if (cat == '갈비' && time != '점심') ribs += val;
        if (cat == '정육' && time != '점심') butcher += val;
        if (cat == '포장') togo += val;
        if (cat != '포장') sectionTotal += val;
      });
      if (time == '점심') lSum = sectionTotal;
      if (time == '주간') dSum = sectionTotal;
      if (time == '야간') nSum = sectionTotal;
    });

    setState(() {
      _lunchTotal = lSum; _dayTotal = dSum; _nightTotal = nSum;
      _grandTotal = _dayTotal + _nightTotal;
      _totalRibs = ribs; _totalButcher = butcher; _totalTogo = togo;
    });
  }

  // --- UI Widgets ---

  Widget _buildMoneyField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, IntegerCommaFormatter()],
        onTap: () { if (controller.text == '0') controller.text = ''; },
        decoration: InputDecoration(
          labelText: label, floatingLabelBehavior: FloatingLabelBehavior.always, hintText: '0', suffixText: '원',
          isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          border: const OutlineInputBorder(), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade400)),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: khakiMain, width: 2.0)),
          fillColor: Colors.white, filled: true,
        ),
      ),
    );
  }

  Widget _buildTotalDisplayBox(String label, int value, Color color) {
    final currencyFormat = NumberFormat('#,###');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0), height: 50,
      decoration: BoxDecoration(color: color.withOpacity(0.08), border: Border.all(color: color), borderRadius: BorderRadius.circular(4)),
      padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.centerRight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          Text("${currencyFormat.format(value)}원", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildCounterField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.remove, size: 16, color: Colors.red), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30), onPressed: () => _adjustValue(controller, -1)),
              Expanded(child: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center, onTap: () { if (controller.text == '0') controller.text = ''; }, decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: '0', contentPadding: EdgeInsets.symmetric(vertical: 8)))),
              IconButton(icon: const Icon(Icons.add, size: 16, color: Colors.blue), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30), onPressed: () => _adjustValue(controller, 1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(int index, String title, Color activeColor) {
    bool isSelected = _currentTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _currentTabIndex = index; }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: isSelected ? activeColor : Colors.grey.shade200, border: Border(bottom: BorderSide(color: isSelected ? activeColor : Colors.grey.shade300, width: 4))),
          child: Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black54)),
        ),
      ),
    );
  }

  Widget _buildLunchSection() {
    if (!_salesTimeCtrls.containsKey('점심')) return const SizedBox.shrink();
    final lunchCats = _salesTimeCtrls['점심']!;
    return Container(
      margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: khakiLight.withOpacity(0.05), border: Border.all(color: khakiMain.withOpacity(0.5)), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(children: [Text('점심 매출', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: khakiMain)), Text(" (합계 제외)", style: TextStyle(fontSize: 12, color: Colors.grey))]),
          const Divider(),
          Wrap(spacing: 8, children: _salesCategoryKeys.map((cat) => SizedBox(width: (MediaQuery.of(context).size.width / 2) - 30, child: _buildMoneyField(cat, lunchCats[cat]!))).toList()),
          _buildTotalDisplayBox('소계', _lunchTotal, taupelight),
          const SizedBox(height: 12),
          SizedBox(height: 40, child: ElevatedButton.icon(onPressed: () => _showSectionApplyDialog('점심'), icon: const Icon(Icons.check, size: 18), label: const Text('점심 매출 입력'), style: ElevatedButton.styleFrom(backgroundColor: desertgray, foregroundColor: Colors.white, elevation: 0))),
        ],
      ),
    );
  }

  Widget _buildDayNightTabContent({required String title, required Color themeColor}) {
    // 🚀 [핵심 수정] 컨트롤러가 아직 생성되지 않았을 경우를 대비한 방어 코드
    if (!_salesTimeCtrls.containsKey(title) || !_menuVolumeCtrls.containsKey(title)) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // 이제 안전하게 값을 가져올 수 있습니다.
    final cats = _salesTimeCtrls[title]!;
    final menus = _menuVolumeCtrls[title]!;

    // 아래 가공 로직은 _menuKeys를 사용하도록 수정된 버전 유지
    final displayItems = _menuKeys.where((item) => !item.contains('숯') && !item.contains('쌀')).toList();
    int totalVal = (title == '주간') ? _dayTotal : _nightTotal;

    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(color: khakiLight.withOpacity(0.08), border: Border.all(color: khakiMain.withOpacity(0.3)), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title 매출', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: khakiMain)),
          const SizedBox(height: 15),
          Wrap(spacing: 8, children: _salesCategoryKeys.map((cat) => SizedBox(width: (MediaQuery.of(context).size.width / 2) - 34, child: _buildMoneyField(cat, cats[cat]!))).toList()),
          _buildTotalDisplayBox('소계', totalVal, taupelight),
          Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Divider(thickness: 1, color: khakiMain.withOpacity(0.3))),
          Row(children: [Icon(Icons.restaurant_menu, color: khakiMain), const SizedBox(width: 8), Text('$title 메뉴 판매량', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: khakiMain))]),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.5, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: displayItems.length,
            itemBuilder: (context, index) => _buildCounterField(displayItems[index], menus[displayItems[index]]!),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 45, child: ElevatedButton.icon(onPressed: () => _showSectionApplyDialog(title), icon: const Icon(Icons.check, size: 18), label: Text('$title 매출 적용'), style: ElevatedButton.styleFrom(backgroundColor: desertgray, foregroundColor: Colors.white, elevation: 0))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isConfigLoading) return const Center(child: CircularProgressIndicator(color: khakiMain));
    final currencyFormat = NumberFormat('#,###원');
    final tabTimes = _salesTimeKeys.where((t) => t != '점심').toList();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('매출 및 판매량 입력', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: khakiMain)),
            const SizedBox(height: 15),
            _buildLunchSection(),
            const SizedBox(height: 20),
            Column(
              children: [
                Row(children: tabTimes.asMap().entries.map((e) => _buildTabButton(e.key, e.value, e.key == 0 ? khakiMain : dullbrown)).toList()),
                _buildDayNightTabContent(
                  title: tabTimes.isNotEmpty && _currentTabIndex < tabTimes.length
                      ? tabTimes[_currentTabIndex]
                      : (tabTimes.isNotEmpty ? tabTimes[0] : ""),
                  themeColor: _currentTabIndex == 0 ? Colors.blue : Colors.indigo,
                )
              ],
            ),
            const SizedBox(height: 30),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: dullbrown, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 5, spreadRadius: 1)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('오늘의 총 매출', style: TextStyle(color: Colors.white, fontSize: 16)), Text(currencyFormat.format(_grandTotal), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))]),
                  const Divider(color: Colors.white54),
                  const Text('(주간 + 야간 합계, 포장 제외)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 5),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('갈비: ${currencyFormat.format(_totalRibs)}', style: const TextStyle(color: Colors.white)), Text('정육: ${currencyFormat.format(_totalButcher)}', style: const TextStyle(color: Colors.white)), Text('포장(별도): ${currencyFormat.format(_totalTogo)}', style: const TextStyle(color: Colors.white70))]),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed: _showSalesCheckDialog, icon: const Icon(Icons.save_alt), label: const Text('매출 내용 저장'), style: ElevatedButton.styleFrom(backgroundColor: khakiMain, foregroundColor: Colors.white))),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- 기존 도우미 함수들 ---
  void _adjustValue(TextEditingController controller, double amount) {
    double currentValue = double.tryParse(controller.text.replaceAll(',', '')) ?? 0.0;
    double newValue = currentValue + amount;
    if (newValue < 0) newValue = 0;
    controller.text = (newValue % 1 == 0) ? newValue.toInt().toString() : newValue.toString();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📋 내용이 복사되었습니다!'), behavior: SnackBarBehavior.floating));
  }

  void _showSectionApplyDialog(String section) {
    FocusScope.of(context).unfocus();
    _updateTotal();
    final cats = _salesTimeCtrls[section]!;
    final menus = _menuVolumeCtrls[section];
    int totalValue = (section == '점심') ? _lunchTotal : (section == '주간' ? _dayTotal : _nightTotal);
    final currencyFormat = NumberFormat('#,###원');
    StringBuffer sb = StringBuffer();
    sb.writeln("$section 매출 내역");
    sb.writeln("-------------------------");
    cats.forEach((key, ctrl) => sb.writeln(" • $key: ${ctrl.text.isEmpty ? '0' : ctrl.text}원"));
    sb.writeln("-------------------------");
    sb.writeln("-------------------------");
    sb.writeln("소계: ${currencyFormat.format(totalValue)}");
    if (menus != null) {
      // 🚀 [수정] _menuKeys 사용
      List<String> displayItems = _menuKeys.where((item) => !item.contains('숯') && !item.contains('쌀')).toList();
      double totalQty = 0;
      for (String key in displayItems) {
        double qty = double.tryParse(menus[key]?.text.replaceAll(',', '') ?? '0') ?? 0;
        if (qty > 0) {
          sb.writeln(" • $key: ${(qty % 1 == 0) ? qty.toInt() : qty}개");
          totalQty += qty;
        }
      }
    }
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text('$section 매출 적용'), content: SingleChildScrollView(child: Text(sb.toString())), actions: [TextButton.icon(onPressed: () => _copyToClipboard(sb.toString()), icon: const Icon(Icons.copy, size: 16), label: const Text("복사")), ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text("확인"))]));
  }

  void _showSalesCheckDialog() {
    final currencyFormat = NumberFormat('#,###원');
    StringBuffer sb = StringBuffer();
    // 🚀 [수정] _menuKeys 사용
    List<String> displayItems = _menuKeys.where((item) => !item.contains('숯') && !item.contains('쌀')).toList();
    sb.writeln("💰 [총 매출 합계]: ${currencyFormat.format(_grandTotal)}");
    sb.writeln("\n🍜 [메뉴별 판매 수량]");
    _menuVolumeCtrls.forEach((time, menus) {
      sb.writeln("-- $time --");
      for (String key in displayItems) {
        if ((double.tryParse(menus[key]?.text ?? '0') ?? 0) > 0) sb.writeln(" • $key: ${menus[key]!.text}개");
      }
    });
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("💰 최종 제출 확인"), content: SingleChildScrollView(child: Text(sb.toString())), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")), ElevatedButton(onPressed: () async { try { await _saveToDB(); if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 저장 완료!'), backgroundColor: khakiMain)); } } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ 저장 실패: $e'), backgroundColor: Colors.red)); } }, child: const Text("제출"))]));
  }
}

class IntegerCommaFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (newText.isEmpty) return newValue.copyWith(text: '');
    final String newString = NumberFormat('#,###').format(int.parse(newText));
    return TextEditingValue(text: newString, selection: TextSelection.collapsed(offset: newString.length));
  }
}
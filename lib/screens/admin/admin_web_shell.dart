// lib/screens/admin/admin_web_shell.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../common/constants.dart';
import '../../services/report_service.dart';
import 'admin_report_detail_page.dart';

class AdminWebDashboard extends StatefulWidget {
  const AdminWebDashboard({super.key});

  @override
  State<AdminWebDashboard> createState() => _AdminWebDashboardState();
}

class _AdminWebDashboardState extends State<AdminWebDashboard> {
  int _selectedIndex = 0;

  // 🚀 [해결] 초기값을 선언과 동시에 확실하게 부여합니다.
  DateTime _selectedDate = DateTime.now();
  DateTime _analysisStartDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _analysisEndDate = DateTime.now();

  final currencyFormat = NumberFormat.simpleCurrency(locale: 'ko_KR', name: '', decimalDigits: 0);
  List<Map<String, dynamic>> _stores = [];
  bool _isLoading = false;

  String _selectedMetric = "총매출";
  String _selectedStoreId = "all";
  String _chartType = "line";
  List<Map<String, dynamic>> _chartRawData = [];

  @override
  void initState() {
    super.initState();
    // 🚀 [해결] 초기 데이터 로드를 안전하게 수행합니다.
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final stores = await ReportService().getAllStores();
      if (mounted) {
        setState(() => _stores = stores);
        _fetchChartData();
      }
    } catch (e) {
      debugPrint("매장 로드 에러: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // 🧱 공통 레이아웃
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSideBar(),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: Container(color: Colors.white, child: _buildMainContent())),
        ],
      ),
    );
  }

  Widget _buildSideBar() {
    return NavigationRail(
      backgroundColor: Colors.grey[50],
      extended: true,
      minExtendedWidth: 200,
      selectedIndex: _selectedIndex,
      onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
      leading: const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Text("MA GAM", style: TextStyle(color: khakiMain, fontWeight: FontWeight.bold, fontSize: 24)),
      ),
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('실시간 현황')),
        NavigationRailDestination(icon: Icon(Icons.analytics), label: Text('매출 분석')),
      ],
    );
  }

  Widget _buildMainContent() {
    if (_selectedIndex == 0) return _buildStoreStatusTable();
    return _buildSalesAnalysisTab();
  }

  // ---------------------------------------------------------------------------
  // 📊 매출 분석 탭 (Y축 만원 단위 + 직선 + 기간 선택)
  // ---------------------------------------------------------------------------

  Widget _buildSalesAnalysisTab() {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalysisHeader(),
          const SizedBox(height: 25),
          _buildChartFilterBar(),
          const SizedBox(height: 30),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 40, 40, 20),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: khakiMain))
                  : _chartRawData.isEmpty
                  ? const Center(child: Text("데이터가 없습니다."))
                  : _chartType == "line" ? _buildLineChart() : _buildBarChart(),
            ),
          ),
        ],
      ),
    );
  }

  // 1. 기간 및 월 이동을 위한 도우미 함수들

// 🚀 퀵 버튼 설정 (1달 / 1년)
  void _setQuickPeriod(String type) {
    DateTime now = DateTime.now();
    setState(() {
      if (type == "month") {
        _analysisStartDate = DateTime(now.year, now.month, 1);
        _analysisEndDate = now;
      } else if (type == "year") {
        _analysisStartDate = DateTime(now.year, 1, 1);
        _analysisEndDate = now;
      }
    });
    _fetchChartData();
  }

// 🚀 월 이동 (이전달 / 다음달)
  void _moveMonth(int offset) {
    setState(() {
      // 시작일을 기준으로 월 이동
      DateTime newStart = DateTime(_analysisStartDate.year, _analysisStartDate.month + offset, 1);
      // 해당 월의 마지막 날 계산
      DateTime newEnd = DateTime(_analysisStartDate.year, _analysisStartDate.month + offset + 1, 0);

      // 오늘 날짜를 넘어가지 않도록 방어 코드
      if (newEnd.isAfter(DateTime.now())) {
        newEnd = DateTime.now();
      }

      _analysisStartDate = newStart;
      _analysisEndDate = newEnd;
    });
    _fetchChartData();
  }

// 2. 수정된 분석 탭 헤더 UI
  Widget _buildAnalysisHeader() {
    if (_analysisStartDate == null || _analysisEndDate == null) return const SizedBox();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("매출 추이 분석", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                // 🚀 월 이동 화살표 (이전)
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.grey),
                  onPressed: () => _moveMonth(-1),
                  tooltip: "이전 달",
                ),
                // 기간 표시
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${DateFormat('yyyy-MM-dd').format(_analysisStartDate)} ~ ${DateFormat('yyyy-MM-dd').format(_analysisEndDate)}",
                    style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                // 🚀 월 이동 화살표 (다음)
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.grey),
                  onPressed: () => _moveMonth(1),
                  tooltip: "다음 달",
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            // 🚀 퀵 버튼: 1달
            OutlinedButton(
              onPressed: () => _setQuickPeriod("month"),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: const BorderSide(color: Colors.grey)),
              child: const Text("1달"),
            ),
            const SizedBox(width: 8),
            // 🚀 퀵 버튼: 1년
            OutlinedButton(
              onPressed: () => _setQuickPeriod("year"),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: const BorderSide(color: Colors.grey)),
              child: const Text("1년"),
            ),
            const SizedBox(width: 15),
            // 기존 기간 설정 버튼
            ElevatedButton.icon(
              onPressed: () => _selectAnalysisRange(context),
              icon: const Icon(Icons.date_range, size: 18),
              label: const Text("기간 직접 설정"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 1. 데이터를 가져오고 날짜별로 합산하는 함수 (강력한 버전)
  Future<void> _fetchChartData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final rawData = await ReportService().getSalesDataForRange(
        start: _analysisStartDate,
        end: _analysisEndDate,
        storeId: _selectedStoreId,
      );

      List<Map<String, dynamic>> processedData = [];

      if (_selectedStoreId == "all") {
        // 🚀 날짜별 합산 로직 (날짜당 무조건 1개의 데이터만 남김)
        Map<String, Map<String, dynamic>> dailyMap = {};

        for (var doc in rawData) {
          String date = doc['date'];
          if (!dailyMap.containsKey(date)) {
            dailyMap[date] = {
              'date': date,
              'grandTotal': 0,
              'morning': 0,
              'night': 0,
            };
          }
          // 금액 합산
          dailyMap[date]!['grandTotal'] += (doc['grandTotal'] ?? 0);

          // 상세 매출 합산 (주간/야간)
          if (doc['salesTime'] != null) {
            final sTime = doc['salesTime'];
            if (sTime['주간'] != null) {
              dailyMap[date]!['morning'] += (sTime['주간']['갈비'] ?? 0) + (sTime['주간']['정육'] ?? 0);
            }
            if (sTime['야간'] != null) {
              dailyMap[date]!['night'] += (sTime['야간']['갈비'] ?? 0) + (sTime['야간']['정육'] ?? 0);
            }
          }
        }
        processedData = dailyMap.values.toList();
      } else {
        // 단일 매장은 합산 없이 그대로 사용
        processedData = rawData;
      }

      // 🚀 날짜순으로 최종 정렬
      processedData.sort((a, b) => a['date'].compareTo(b['date']));

      if (mounted) {
        setState(() {
          _chartRawData = processedData; // 이 리스트에는 이제 날짜 중복이 절대 없습니다.
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("차트 데이터 가공 실패: $e");
    }
  }

// 2. 그래프에서 값을 읽어오는 함수 (구조 통합)
  num _calculateValue(Map<String, dynamic> data) {
    if (_selectedStoreId == "all") {
      // 합산 데이터 구조에서 읽기
      if (_selectedMetric == "주간매출") return data['morning'] ?? 0;
      if (_selectedMetric == "야간매출") return data['night'] ?? 0;
      return data['grandTotal'] ?? 0;
    } else {
      // 단일 매장 원본 데이터 구조에서 읽기
      if (_selectedMetric == "주간매출") {
        final s = data['salesTime']?['주간'];
        return s == null ? 0 : (s['갈비'] ?? 0) + (s['정육'] ?? 0);
      }
      if (_selectedMetric == "야간매출") {
        final s = data['salesTime']?['야간'];
        return s == null ? 0 : (s['갈비'] ?? 0) + (s['정육'] ?? 0);
      }
      return data['grandTotal'] ?? 0;
    }
  }

// 3. 선 그래프 빌더 (직선 + 중복 차단)
  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        // 🚀 [추가] 툴팁 숫자 포맷팅 설정
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            // 🚀 [수정] getTooltipColor 대신 tooltipBgColor 사용
            tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                return LineTooltipItem(
                  '${currencyFormat.format(touchedSpot.y)}원',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: _buildChartTitles(),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: _getSpots(),
            isCurved: false,
            color: khakiMain,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: khakiMain.withOpacity(0.05)),
          ),
        ],
      ),
    );
  }

// 4. 차트 타이틀(날짜 라벨) 설정
  FlTitlesData _buildChartTitles() {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 60,
          getTitlesWidget: (value, meta) {
            if (value == 0) return const SizedBox();
            return Text("${(value / 10000).toInt()}만", style: const TextStyle(fontSize: 10, color: Colors.grey));
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
            showTitles: true,
            // 🚀 핵심 수정: 1단위(정수)로만 타이틀을 그리도록 강제함 (중복 방지)
            interval: 1,
            getTitlesWidget: (v, m) {
              int idx = v.toInt();
              // 범위 밖이거나 데이터가 없으면 출력 안함
              if (idx < 0 || idx >= _chartRawData.length) return const SizedBox();

              String dateStr = _chartRawData[idx]['date'].toString();
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(dateStr.substring(5), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              );
            }
        ),
      ),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        // 🚀 [추가] 툴팁 숫자 포맷팅 설정
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            // 🚀 [수정] getTooltipColor 대신 tooltipBgColor 사용
            tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${currencyFormat.format(rod.toY)}원',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              );
            },
          ),
        ),
        titlesData: _buildChartTitles(),
        borderData: FlBorderData(show: false),
        barGroups: _getBarGroups(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 📋 실시간 현황 탭 (요약 카드 + 테이블)
  // ---------------------------------------------------------------------------

  Widget _buildStoreStatusTable() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        ReportService().getAdminDashboardData(_selectedDate),
        ReportService().getMonthlyStoreTotals(_selectedDate),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: khakiMain));

        final dailyData = snapshot.data![0];
        final monthlyMap = snapshot.data![1] as Map<String, int>;
        int grandMonthlyTotal = 0;
        monthlyMap.forEach((k, v) => grandMonthlyTotal += v);

        final stores = dailyData['stores'] as List;
        final salesMap = dailyData['sales'] as Map;
        final statusMap = dailyData['status'] as Map;

        int dailySum = 0;
        int completed = 0;
        for (var s in stores) {
          final uid = s['uid'];
          dailySum += (salesMap[uid]?['total'] ?? 0) as int;
          if (statusMap[uid] == 'complete') completed++;
        }

        return Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDashboardHeader(),
              const SizedBox(height: 25),
              _buildSummaryCards(dailySum, grandMonthlyTotal, completed, stores.length),
              const SizedBox(height: 30),
              Expanded(child: _buildEnhancedTable(List<Map<String, dynamic>>.from(stores), Map<String, String>.from(statusMap), Map<String, dynamic>.from(salesMap))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboardHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text("${DateFormat('yyyy-MM-dd').format(_selectedDate)} 매장 현황",
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            IconButton(icon: const Icon(Icons.calendar_month, color: khakiMain, size: 28), onPressed: () => _selectDate(context)),
          ],
        ),
        IconButton(icon: const Icon(Icons.refresh, color: khakiMain, size: 28), onPressed: () => setState(() {})),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 🛠️ 도우미 함수 및 필터 위젯들
  // ---------------------------------------------------------------------------

  Future<void> _selectAnalysisRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _analysisStartDate, end: _analysisEndDate),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: khakiMain)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _analysisStartDate = picked.start;
        _analysisEndDate = picked.end;
      });
      _fetchChartData();
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  List<FlSpot> _getSpots() {
    return List.generate(_chartRawData.length, (i) {
      return FlSpot(i.toDouble(), _calculateValue(_chartRawData[i]).toDouble());
    });
  }

  List<BarChartGroupData> _getBarGroups() {
    return List.generate(_chartRawData.length, (i) {
      return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: _calculateValue(_chartRawData[i]).toDouble(), color: khakiMain, width: 14)]);
    });
  }

  num _sum(Map<String, dynamic>? sales) {
    if (sales == null) return 0;
    return (sales['갈비'] ?? 0) + (sales['정육'] ?? 0);
  }

  Widget _buildSummaryCards(int total, int monthly, int completed, int totalCount) {
    return Row(
      children: [
        _cardItem("오늘의 총 매출", "${currencyFormat.format(total)}원", Icons.payments, Colors.blue),
        const SizedBox(width: 20),
        _cardItem("당월 누계(MTD)", "${currencyFormat.format(monthly)}원", Icons.analytics, khakiMain),
        const SizedBox(width: 20),
        _cardItem("보고 완료 현황", "$completed / $totalCount", Icons.task_alt, Colors.green),
      ],
    );
  }

  Widget _cardItem(String t, String v, IconData i, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: c.withOpacity(0.2))),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: c.withOpacity(0.1), radius: 25, child: Icon(i, color: c)),
            const SizedBox(width: 20),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedTable(List<Map<String, dynamic>> stores, Map<String, String> statusMap, Map<String, dynamic> salesData) {
    return Card(child: SingleChildScrollView(child: SizedBox(width: double.infinity, child: DataTable(
      columns: const [DataColumn(label: Text('매장명')), DataColumn(label: Text('주간 매출')), DataColumn(label: Text('야간 매출')), DataColumn(label: Text('총 매출')), DataColumn(label: Text('상태')), DataColumn(label: Text('상세'))],
      rows: stores.map((s) {
        final uid = s['uid'];
        final sales = salesData[uid] ?? {'morning': 0, 'night': 0, 'total': 0};
        return DataRow(cells: [
          DataCell(Text(kStoreNames[s['storeCode']] ?? s['storeCode'], style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(currencyFormat.format(sales['morning']))),
          DataCell(Text(currencyFormat.format(sales['night']))),
          DataCell(Text(currencyFormat.format(sales['total']), style: const TextStyle(color: khakiMain, fontWeight: FontWeight.bold))),
          DataCell(_buildStatusIcon(statusMap[uid] ?? "")),
          DataCell(IconButton(icon: const Icon(Icons.open_in_new, color: khakiMain), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AdminReportDetailPage(uid: uid, storeName: kStoreNames[s['storeCode']] ?? s['storeCode'], date: _selectedDate))))),
        ]);
      }).toList(),
    ))));
  }

  Widget _buildChartFilterBar() {
    return Wrap(
      spacing: 20, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _filterLabel("매출항목:"),
        _buildSimpleDropdown(["총매출", "주간매출", "야간매출"], _selectedMetric, (v) => setState(() => _selectedMetric = v!)),
        _filterLabel("매장선택:"),
        _buildStoreDropdown(),
        _filterLabel("형태:"),
        _buildChartTypeToggle(),
      ],
    );
  }

  Widget _buildSimpleDropdown(List<String> items, String value, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButton<String>(
        value: value, underline: const SizedBox(),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildStoreDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButton<String>(
        value: _selectedStoreId, underline: const SizedBox(),
        items: [
          const DropdownMenuItem(value: "all", child: Text("전체 매장 합계")),
          ..._stores.map((s) => DropdownMenuItem(value: s['id'], child: Text(s['name'] ?? ''))),
        ],
        onChanged: (v) {
          setState(() => _selectedStoreId = v!);
          _fetchChartData();
        },
      ),
    );
  }

  Widget _buildChartTypeToggle() {
    return ToggleButtons(
      isSelected: [_chartType == "line", _chartType == "bar"],
      onPressed: (idx) => setState(() => _chartType = idx == 0 ? "line" : "bar"),
      borderRadius: BorderRadius.circular(8), selectedColor: Colors.white, fillColor: khakiMain,
      children: const [Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.show_chart)), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.bar_chart))],
    );
  }

  Widget _filterLabel(String text) => Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54));

  Widget _buildStatusIcon(String s) {
    if (s == 'complete') return const Icon(Icons.check_circle, color: Colors.green);
    if (s == 'writing') return const Icon(Icons.pending, color: Colors.orange);
    return const Icon(Icons.remove, color: Colors.grey);
  }
}
// lib/screens/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/report_service.dart';
import '../models/daily_report_model.dart';
import '../common/constants.dart';
import 'records/widgets/admin_sales_tab.dart';
import 'records/widgets/admin_records_tab.dart';
import 'records/widgets/report_detail_dialog.dart';
import 'admin/store_config_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<Map<String, dynamic>> _stores = [];
  Map<String, DailyReport?> _reports = {};
  Map<String, String> _storeStatuses = {};
  Map<String, int> _monthlyTotals = {}; // 🚀 매장별 월 누계 저장용

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  Future<void> _initDashboard() async {
    await _loadData();
  }

  // 🚀 모든 매장의 보고 상태를 업데이트하는 함수
  void _loadAllStatuses() {
    Map<String, String> statuses = {};
    _reports.forEach((uid, report) {
      statuses[uid] = report?.status ?? "";
    });

    if (mounted) {
      setState(() {
        _storeStatuses = statuses;
      });
    }
  }

  // 🚀 데이터 로드 함수 (일일 보고서 + 월 누계 병렬 로드)
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. 매장 목록 가져오기
      final stores = await ReportService().getAllStores();

      // 🚀 2. 일일 보고서와 월 누계 데이터를 병렬(Future.wait)로 로드하여 속도를 높입니다.
      final results = await Future.wait([
        Future.wait(stores.map((s) => ReportService().getReport(_selectedDate, s['id'].toString()))),
        ReportService().getMonthlyStoreTotals(_selectedDate),
      ]);

      final List<DailyReport?> reportsList = results[0] as List<DailyReport?>;
      final Map<String, int> monthlyTotals = results[1] as Map<String, int>;

      // 3. 맵 형태로 변환
      Map<String, DailyReport?> fetchedReports = {};
      for (int i = 0; i < stores.length; i++) {
        fetchedReports[stores[i]['id'].toString()] = reportsList[i];
      }

      if (mounted) {
        setState(() {
          _stores = stores;
          _reports = fetchedReports;
          _monthlyTotals = monthlyTotals; // 🚀 실제 월 누계 데이터 반영
        });
        _loadAllStatuses();
      }
    } catch (e) {
      print("❌ 데이터 로드 실패: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 날짜 제어 및 상세보기 로직 (기존과 동일하게 유지) ---
  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadData();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: khakiMain)),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  void _showFullDetail(DailyReport? report) {
    if (report == null) return;
    Map<String, dynamic>? storeInfo;
    for (var s in _stores) {
      if (s['id'].toString() == report.storeId) {
        storeInfo = s;
        break;
      }
    }
    storeInfo ??= {'name': report.storeId, 'id': report.storeId, 'storeId': report.storeId};
    final String displayName = storeInfo['name'] ?? storeInfo['storeId'] ?? report.storeId;

    showDialog(
      context: context,
      builder: (context) => ReportDetailDialog(
        report: report,
        title: displayName,
        content: SingleChildScrollView(
          child: Column(
            children: [
              _buildSectionHeader("오전 보고 현황", Icons.wb_sunny_outlined),
              _buildDetailTable("근무인원", report.staffCounts, unit: "명"),
              _buildDetailTable("오전재고", report.morningPrep, unit: "개"),
              _buildDetailList("유통기한 목록", report.expiryLog),
              _buildDetailSection("예약사항", report.reservation),
              _buildDetailSection("오전 특이사항", report.morningNote),
              _buildSectionHeader("매출 및 판매 현황", Icons.bar_chart),
              _buildDetailTable("시간대별 매출", report.salesTime),
              _buildDetailTable("주간판매량", report.dayVolume ?? {}, unit: "개"),
              _buildDetailTable("야간판매량", report.nightVolume ?? {}, unit: "개"),
              _buildSectionHeader("마감 및 정산", Icons.nights_stay_outlined),
              _buildDetailTable("마감내역", {"총 매출액": report.grandTotal, ...report.cashFlow, "카드매출": report.cardSales}),
              _buildDetailList("지출내역", report.expenseList),
              _buildDetailSection("입사", report.hiring),
              _buildDetailSection("퇴사", report.leaving),
              _buildDetailSection("마감 특이사항", report.closingNote),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI 헬퍼 메서드들 (생략 없이 모두 유지) ---
  Widget _buildDetailTable(String title, Map<String, dynamic> data, {String unit = '원'}) {
    final currencyFormat = NumberFormat('#,###');
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: khakiMain, fontSize: 16)),
          const Divider(color: khakiMain, thickness: 1),
          const SizedBox(height: 8),
          Table(
            border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
            columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1.5)},
            children: data.entries.map((entry) {
              if (entry.value is Map) {
                final Map innerMap = entry.value;
                final String formattedContent = innerMap.entries.map((innerEntry) {
                  final value = innerEntry.value;
                  final formattedValue = (value is num) ? "${currencyFormat.format(value)}$unit" : value.toString();
                  return "${innerEntry.key}: $formattedValue";
                }).join('\n');
                return TableRow(children: [
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))),
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(formattedContent, style: const TextStyle(height: 1.4, fontSize: 13))),
                ]);
              }
              return TableRow(children: [
                Padding(padding: const EdgeInsets.all(8.0), child: Text(entry.key, style: const TextStyle(color: Colors.black54))),
                Padding(padding: const EdgeInsets.all(8.0), child: Text(entry.value is num ? currencyFormat.format(entry.value) : entry.value.toString(), style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              ]);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailList(String title, List<Map<String, dynamic>> listData) {
    if (listData.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: khakiMain, fontSize: 16)),
          const Divider(color: khakiMain, thickness: 1),
          const SizedBox(height: 8),
          ...listData.map((item) => Container(
            width: double.infinity, margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300, width: 0.5)),
            child: Text(item.entries.map((e) => "${e.key}: ${e.value}").join("  |  "), style: const TextStyle(fontSize: 13, color: Colors.black87)),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Icon(icon, color: khakiMain, size: 22),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: khakiMain)),
          const SizedBox(width: 10),
          const Expanded(child: Divider(thickness: 2, color: khakiMain)),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, String? content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: khakiMain, fontSize: 16)),
          const Divider(color: khakiMain, thickness: 1),
          const SizedBox(height: 8),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
            child: Text(content ?? '기록된 내용이 없습니다.', style: const TextStyle(height: 1.5)),
          ),
        ],
      ),
    );
  }

  void _showStoreSelectDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("매장 항목 설정"),
        content: SizedBox(
          width: double.maxFinite,
          child: _stores.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              : ListView.builder(
            shrinkWrap: true,
            itemCount: _stores.length,
            itemBuilder: (context, index) {
              final store = _stores[index];
              final String rawName = store['name'] ?? '이름 없음';
              final String displayName = kStoreNames[rawName] ?? rawName;
              return ListTile(
                leading: const Icon(Icons.store, color: khakiMain),
                title: Text(displayName),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => StoreConfigScreen(storeUid: store['id'], storeName: displayName)));
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("닫기"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: khakiMain,
          title: const Text("본부장 대시보드"),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [Tab(text: "전체 매장"), Tab(text: "매장별 기록")],
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'settings') _showStoreSelectDialog();
                else if (value == 'refresh') _loadData();
                else if (value == 'logout') Navigator.pushReplacementNamed(context, '/login');
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings), SizedBox(width: 10), Text("매장 항목 설정")])),
                const PopupMenuItem(value: 'refresh', child: Row(children: [Icon(Icons.refresh), SizedBox(width: 10), Text("데이터 새로고침")])),
                const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, color: Colors.redAccent), SizedBox(width: 10), Text("로그아웃")])),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            _buildDateSelector(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: khakiMain))
                  : TabBarView(
                children: [
                  // 🚀 [해결 지점] AdminSalesTab에 monthlyTotals를 전달합니다.
                  AdminSalesTab(
                      stores: _stores,
                      reports: _reports,
                      storeStatuses: _storeStatuses,
                      monthlyTotals: _monthlyTotals, // 👈 에러 해결의 핵심
                      onStoreTap: _showFullDetail
                  ),
                  AdminRecordsTab(stores: _stores, onStoreTap: _showFullDetail),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2, offset: const Offset(0, 1))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left, color: khakiMain), onPressed: () => _changeDate(-1)),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: khakiMain.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, size: 18, color: khakiMain),
                  const SizedBox(width: 8),
                  Text(DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, color: khakiMain, fontSize: 16)),
                ],
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.chevron_right, color: khakiMain), onPressed: () => _changeDate(1)),
        ],
      ),
    );
  }
}
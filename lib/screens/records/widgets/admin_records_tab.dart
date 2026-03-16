// lib/screens/records/widgets/admin_records_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/daily_report_model.dart';
import '../../../common/constants.dart';
import '../../../services/report_service.dart';

class AdminRecordsTab extends StatefulWidget {
  final List<Map<String, dynamic>> stores;
  final Function(DailyReport?) onStoreTap; // 🚀 상세 팝업 함수
  final String periodMode;                 // 🚀 '월별', '년별', '전체'
  final DateTime targetDate;               // 🚀 선택된 기준 날짜

  const AdminRecordsTab({
    super.key,
    required this.stores,
    required this.onStoreTap,
    required this.periodMode,
    required this.targetDate,
  });

  @override
  State<AdminRecordsTab> createState() => _AdminRecordsTabState();
}

class _AdminRecordsTabState extends State<AdminRecordsTab> {
  String? _selectedStoreId;
  List<DailyReport> _history = [];
  bool _isHistoryLoading = false;
  int _totalSalesSum = 0; // 선택 기간 총 매출 합계
  List<Map<String, dynamic>> _storeSummaries = [];

  @override
  void didUpdateWidget(covariant AdminRecordsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 🚀 모드나 날짜가 바뀌면 데이터를 다시 불러옵니다.
    if ((oldWidget.periodMode != widget.periodMode || oldWidget.targetDate != widget.targetDate) && _selectedStoreId != null) {
      _fetchHistory(_selectedStoreId!);
    }
  }

  Future<void> _fetchHistory(String storeId) async {
    setState(() {
      _selectedStoreId = storeId;
      _isHistoryLoading = true;
      _history = [];
      _storeSummaries = []; // 요약 바구니 초기화
      _totalSalesSum = 0;
    });

    int grandTotalSum = 0;

    try {
      if (storeId == 'all') {
        // 🚀 [1] 전체 매장 모드: 기존처럼 매장별 합계
        for (var store in widget.stores) {
          final String uid = (store['id'] ?? store['uid'] ?? '').toString();
          final String engName = (store['storeId'] ?? '').toString();
          final String storeName = kStoreNames[engName] ?? engName;
          if (uid.isEmpty) continue;

          final results = await ReportService().getStoreReportHistory(uid);
          final filtered = _filterByMode(results); // 아래에 만든 필터 함수 사용

          if (filtered.isNotEmpty) {
            int storeSum = 0;
            for (var r in filtered) { storeSum += r.grandTotal.toInt(); }
            _storeSummaries.add({'type': 'STORE', 'name': storeName, 'total': storeSum, 'count': filtered.length});
            grandTotalSum += storeSum;
          }
        }
        _storeSummaries.sort((a, b) => b['total'].compareTo(a['total']));
      } else {
        // 🚀 [2] 개별 매장 모드
        final results = await ReportService().getStoreReportHistory(storeId);
        final filtered = _filterByMode(results);
        for (var r in filtered) { grandTotalSum += r.grandTotal.toInt(); }

        if (widget.periodMode == '년별') {
          // 📈 [핵심] 년별 모드면 일일 내역 대신 '월별 합계'를 계산합니다.
          Map<int, int> monthlyMap = {};
          for (var r in filtered) {
            int month = DateTime.parse(r.date).month;
            monthlyMap[month] = (monthlyMap[month] ?? 0) + r.grandTotal.toInt();
          }
          // 12월부터 1월 역순으로 요약 바구니에 담기
          for (int m = 12; m >= 1; m--) {
            if (monthlyMap.containsKey(m)) {
              _storeSummaries.add({'type': 'MONTH', 'name': '$m월 매출 합계', 'total': monthlyMap[m], 'count': 0});
            }
          }
        } else {
          // 📅 월별/전체 모드면 기존처럼 일일 내역 표시
          _history = filtered..sort((a, b) => b.date.compareTo(a.date));
        }
      }
    } catch (e) { print("데이터 로드 에러: $e"); }

    if (mounted) setState(() { _totalSalesSum = grandTotalSum; _isHistoryLoading = false; });
  }

  // 🚀 기간 필터링 로직 공통화
  List<DailyReport> _filterByMode(List<DailyReport> reports) {
    return reports.where((report) {
      if (widget.periodMode == '전체') return true;
      try {
        DateTime rDate = DateTime.parse(report.date);
        if (widget.periodMode == '월별') {
          return rDate.year == widget.targetDate.year && rDate.month == widget.targetDate.month;
        } else if (widget.periodMode == '년별') {
          return rDate.year == widget.targetDate.year;
        }
      } catch (e) { return false; }
      return false;
    }).toList();
  }

  // 🚀 선택된 모드에 따라 데이터가 진짜 비었는지 확인하는 함수
  bool _isDataEmpty() {
    // 🚀 전체매장이거나, 개별매장의 년별 모드일 때는 요약 바구니를 확인
    if (_selectedStoreId == 'all' || widget.periodMode == '년별') {
      return _storeSummaries.isEmpty;
    }
    return _history.isEmpty;
  }

  Widget _buildHistoryList() {
    // 🚀 요약 리스트를 보여주는 조건 (전체매장 OR 개별매장+년별)
    if (_selectedStoreId == 'all' || widget.periodMode == '년별') {
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _storeSummaries.length,
        itemBuilder: (context, index) {
          final item = _storeSummaries[index];
          final isMonthType = item['type'] == 'MONTH';

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isMonthType ? khakiMain : khakiMain,
                child: Icon(isMonthType ? Icons.calendar_month : Icons.store, color: Colors.white, size: 20),
              ),
              title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(isMonthType ? "${widget.targetDate.year}년 실적" : "매출 보고서 ${item['count']}건"),
              trailing: Text(
                "${NumberFormat('#,###').format(item['total'])}원",
                style: TextStyle(fontWeight: FontWeight.bold, color: isMonthType ? Colors.black87 : khakiMain, fontSize: 16),
              ),
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final report = _history[index];
        final bool isComplete = report.status == 'complete';

        // 🚀 [추가] 전체 매장 모드일 때 매장 이름을 표시하기 위한 로직
        String storeDisplayName = "";
        if (_selectedStoreId == 'all') {
          // report.storeId(또는 uid)를 기반으로 매장명 찾기
          final storeData = widget.stores.firstWhere(
                  (s) => (s['id'] ?? s['uid']) == report.storeId,
              orElse: () => {}
          );
          final String engName = storeData['storeId'] ?? '';
          storeDisplayName = "[${kStoreNames[engName] ?? engName}] ";
        }

        String displayDate = report.date;
        try {
          DateTime dt = DateTime.parse(report.date);
          displayDate = DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(dt);
        } catch (_) {}

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            onTap: () => widget.onStoreTap(report),
            leading: CircleAvatar(
              backgroundColor: isComplete ? khakiMain.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              child: Icon(isComplete ? Icons.check_circle : Icons.pending, color: isComplete ? khakiMain : Colors.orange),
            ),
            // 🚀 매장 이름과 날짜를 함께 표시
            title: Text("$storeDisplayName$displayDate", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text("매출: ${NumberFormat('#,###').format(report.grandTotal)}원"),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStoreSelector(),
        // 🚀 매출 요약 바 (매장이 선택되었을 때만 노출)
        if (_selectedStoreId != null && !_isHistoryLoading) _buildSummaryBar(),
        const Divider(height: 1),
        Expanded(
          child: _selectedStoreId == null
              ? const Center(child: Text("기록을 확인할 매장을 선택해주세요."))
              : _isHistoryLoading
              ? const Center(child: CircularProgressIndicator(color: khakiMain))
          // 🚀 [수정 포인트] 아래에 새로 만든 _isDataEmpty() 함수를 사용합니다.
              : _isDataEmpty()
              ? Center(child: Text("${widget.periodMode} 기록된 보고서가 없습니다."))
              : _buildHistoryList(),
        ),
      ],
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: khakiMain.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: khakiMain.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("선택 기간 총 매출액", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          Text(
            "${NumberFormat('#,###').format(_totalSalesSum)}원",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: khakiMain),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: DropdownButton<String>(
        isExpanded: true,
        hint: const Text("조회할 매장을 선택하세요"),
        value: _selectedStoreId,
        items: [
          // 🚀 1. '전체매장' 옵션을 맨 위에 추가
          const DropdownMenuItem<String>(
            value: 'all',
            child: Text("전체매장", style: TextStyle(fontWeight: FontWeight.bold, color: khakiMain)),
          ),
          // 2. 기존 매장 리스트들
          ...widget.stores.map((store) {
            final String storeUid = (store['id'] ?? store['uid'] ?? '').toString();
            final String englishName = (store['storeId'] ?? '').toString();
            return DropdownMenuItem<String>(
              value: storeUid,
              child: Text(kStoreNames[englishName] ?? englishName),
            );
          }),
        ],
        onChanged: (val) {
          if (val != null) _fetchHistory(val);
        },
      ),
    );
  }
}
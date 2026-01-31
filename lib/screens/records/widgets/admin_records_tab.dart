// lib/screens/records/widgets/admin_records_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/daily_report_model.dart';
import '../../../common/constants.dart';
import '../../../services/report_service.dart';

class AdminRecordsTab extends StatefulWidget {
  final List<Map<String, dynamic>> stores; // 부모로부터 받은 매장 목록
  final Function(DailyReport?) onStoreTap; // 상세 팝업 함수

  const AdminRecordsTab({
    super.key,
    required this.stores,
    required this.onStoreTap,
  });

  @override
  State<AdminRecordsTab> createState() => _AdminRecordsTabState();
}

class _AdminRecordsTabState extends State<AdminRecordsTab> {
  String? _selectedStoreId; // 현재 선택된 매장 ID
  List<DailyReport> _history = [];
  bool _isHistoryLoading = false;

  // 🚀 매장 선택 시 해당 매장의 기록을 불러오는 함수
  Future<void> _fetchHistory(String storeId) async {
    setState(() {
      _selectedStoreId = storeId;
      _isHistoryLoading = true;
    });

    final results = await ReportService().getStoreReportHistory(storeId);

    if (mounted) {
      setState(() {
        _history = results;
        _isHistoryLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 🏪 매장 선택 드롭다운 영역
        _buildStoreSelector(),

        const Divider(height: 1),

        // 📜 기록 리스트 영역
        Expanded(
          child: _selectedStoreId == null
              ? const Center(child: Text("기록을 확인할 매장을 선택해주세요."))
              : _isHistoryLoading
              ? const Center(child: CircularProgressIndicator(color: khakiMain))
              : _history.isEmpty
              ? const Center(child: Text("기록된 보고서가 없습니다."))
              : _buildHistoryList(),
        ),
      ],
    );
  }

  // 🔽 매장 선택 드롭다운 위젯
  Widget _buildStoreSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: DropdownButton<String>(
        isExpanded: true,
        hint: const Text("조회할 매장을 선택하세요"),
        value: _selectedStoreId,
        items: widget.stores.map((store) {
          // 🚀 [수정] id나 uid 중 있는 것을 사용하고, 강제 형변환(as String)을 피합니다.
          final String storeUid = (store['id'] ?? store['uid'] ?? '').toString();
          final String englishName = (store['storeId'] ?? '').toString();

          return DropdownMenuItem<String>(
            value: storeUid,
            child: Text(kStoreNames[englishName] ?? englishName),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) _fetchHistory(val);
        },
      ),
    );
  }

  // 📜 선택된 매장의 이력 리스트 위젯
  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final report = _history[index];
        final bool isComplete = report.status == 'complete';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () => widget.onStoreTap(report), // 상세 팝업 호출
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isComplete ? Icons.check_circle : Icons.pending,
                  color: isComplete ? khakiMain : Colors.orange,
                ),
              ],
            ),
            title: Text(
              report.date, // yyyy-mm-dd 날짜 출력
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "총 매출: ${NumberFormat('#,###').format(report.grandTotal)}원",
              style: const TextStyle(color: Colors.black87),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
          ),
        );
      },
    );
  }
}
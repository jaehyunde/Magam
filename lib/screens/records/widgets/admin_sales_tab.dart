// lib/screens/records/widgets/admin_sales_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/daily_report_model.dart';
import '../../../common/constants.dart';

class AdminSalesTab extends StatelessWidget {
  final List<Map<String, dynamic>> stores;
  final Map<String, DailyReport?> reports;
  final Map<String, String> storeStatuses;
  final Map<String, int> monthlyTotals;
  final Function(DailyReport?) onStoreTap;

  const AdminSalesTab({
    super.key,
    required this.stores,
    required this.reports,
    required this.storeStatuses,
    required this.monthlyTotals,
    required this.onStoreTap,
  });

  Widget _buildStatusBadge(String? status) {
    final lowerStatus = status?.toLowerCase().trim() ?? "";
    Color color;
    String label;
    if (lowerStatus == 'complete') {
      color = Colors.green; label = "작성 완료";
    } else if (lowerStatus == 'writing') {
      color = Colors.orange; label = "작성 중";
    } else {
      color = Colors.grey; label = "작성 전";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), border: Border.all(color: color, width: 1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 1. 오늘 전 지점 매출 합계 계산
    int totalTodayAllStores = 0;
    reports.forEach((key, report) {
      totalTodayAllStores += (report?.grandTotal ?? 0);
    });

    // 🚀 2. 이번 달 전 지점 누계 합계 계산
    int totalMonthlyAllStores = 0;
    monthlyTotals.forEach((key, value) {
      totalMonthlyAllStores += value;
    });

    // 매출액 기준 내림차순 정렬
    final sortedStores = List<Map<String, dynamic>>.from(stores);
    sortedStores.sort((a, b) {
      final sidA = (a['id'] ?? a['uid'] ?? "").toString();
      final sidB = (b['id'] ?? b['uid'] ?? "").toString();
      final totalA = reports[sidA]?.grandTotal ?? 0;
      final totalB = reports[sidB]?.grandTotal ?? 0;
      return totalB.compareTo(totalA);
    });

    return Column(
      children: [
        // 🚀 수정된 요약 카드 호출 (오늘 합계 + 월 누계 합계)
        _buildTotalSummaryCard(totalTodayAllStores, totalMonthlyAllStores),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: sortedStores.length,
            itemBuilder: (context, index) {
              final store = sortedStores[index];
              final String sid = (store['id'] ?? store['uid'] ?? "").toString();
              final report = reports[sid];
              final String status = storeStatuses[sid] ?? "";
              final int monthlyTotal = monthlyTotals[sid] ?? 0;

              final grandTotal = report?.grandTotal ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                child: ListTile(
                  onTap: () => onStoreTap(report),
                  leading: CircleAvatar(
                    backgroundColor: index < 3 ? khakiMain : Colors.grey[300],
                    child: Text("${index + 1}", style: TextStyle(color: index < 3 ? Colors.white : Colors.black87, fontSize: 14)),
                  ),
                  title: Row(
                    children: [
                      Text(store['name'] ?? "매장", style: const TextStyle(fontWeight: FontWeight.bold, color: khakiMain)),
                      const SizedBox(width: 8),
                      _buildStatusBadge(status),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text("매출: ${NumberFormat('#,###').format(grandTotal)}원", style: const TextStyle(fontWeight: FontWeight.bold, color: khakiMain)),
                      Text("월 누계: ${NumberFormat('#,###').format(monthlyTotal)}원", style: const TextStyle(color: khakiMain, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 🚀 [수정] 오늘 합계와 월 누계를 동시에 보여주는 요약 카드
  Widget _buildTotalSummaryCard(int dailyTotal, int monthlyTotal) {
    final currency = NumberFormat('#,###');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: khakiMain,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("전 지점 당일 총 매출", style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text("₩ ${currency.format(dailyTotal)}",
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Colors.white24, thickness: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("전 지점 당월 누계", style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text("₩ ${currency.format(monthlyTotal)}",
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
            ],
          ),
        ],
      ),
    );
  }
}
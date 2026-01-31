import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/report_service.dart';
import '../../models/daily_report_model.dart';
import '../../common/constants.dart';

class AdminReportDetailPage extends StatelessWidget {
  final String uid;
  final String storeName;
  final DateTime date;

  const AdminReportDetailPage({
    super.key,
    required this.uid,
    required this.storeName,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,###원');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('$storeName 상세 보고서'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: FutureBuilder<DailyReport?>(
        future: ReportService().getReport(date, uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text("에러: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: Text("데이터가 없습니다."));

          final r = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // 1. 기본 정보 섹션
                _buildInfoCard(r),
                const SizedBox(height: 24),

                // 2. 인원 및 운영 현황
                _buildSectionHeader("인원 및 운영 현황"),
                _buildStaffTable(r.staffCounts),
                _buildReservationBox(r.reservation),
                const SizedBox(height: 24),

                // 3. 매출 및 정산 상세
                _buildSectionHeader("매출 및 정산 상세"),
                _buildSalesTable(r, currencyFormat),
                _buildFinancialList(r, currencyFormat),
                const SizedBox(height: 24),

                // 4. 재고 및 비용 현황
                _buildSectionHeader("재고 및 비용 현황"),
                _buildInventoryTable(r.inventoryLog),
                _buildExpenseTable(r.expenseList, currencyFormat),
                _buildIntegratedPrepSection(r.morningPrep, r.expiryLog),
                const SizedBox(height: 24),

                // 5. 메모 및 HR 정보
                _buildSectionHeader("메모 및 인사 정보"),
                _buildNoteSection(r),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- 도움 위젯: 섹션 헤더 ---
  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  // --- 도움 위젯: 기본 정보 카드 ---
  Widget _buildInfoCard(DailyReport r) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _infoItem("보고 날짜", r.date),
            _infoItem("작성자", r.author),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    ]);
  }

  // --- 도움 위젯: 인원 현황 표 ---
  Widget _buildStaffTable(Map<String, dynamic> staff) {
    return Card(
      child: DataTable(
        columns: const [DataColumn(label: Text('구분')), DataColumn(label: Text('사장')), DataColumn(label: Text('주방')), DataColumn(label: Text('홀')), DataColumn(label: Text('정육'))],
        rows: ['오전', '오후', '야간'].map((time) {
          final t = staff[time] ?? {};
          return DataRow(cells: [
            DataCell(Text(time, style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text("${t['사장'] ?? 0}")), DataCell(Text("${t['주방'] ?? 0}")),
            DataCell(Text("${t['홀'] ?? 0}")), DataCell(Text("${t['정육'] ?? 0}")),
          ]);
        }).toList(),
      ),
    );
  }

  // --- 도움 위젯: 품질 및 예약 그리드 (에러 해결용 추가) ---
  Widget _buildReservationBox(String res) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: const Icon(Icons.event_note, color: khakiMain),
        title: const Text("오늘의 예약 현황", style: TextStyle(fontSize: 14, color: khakiLight)),
        subtitle: Text(
          res.isEmpty ? "예약 사항 없음" : res,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: khakiMain),
        ),
      ),
    );
  }

  // --- 도움 위젯: 매출 상세 테이블 ---
  Widget _buildSalesTable(DailyReport r, NumberFormat f) {
    return Card(
      child: ExpansionTile(
        title: const Text("시간대별 매출 상세", style: TextStyle(fontWeight: FontWeight.bold)),
        children: ['점심', '주간', '야간'].map((time) {
          final items = r.salesTime[time] as Map<String, dynamic>? ?? {};
          return Column(
            children: [
              ListTile(dense: true, title: Text(time, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
              ...items.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(e.key), Text(f.format(e.value))]),
              )).toList(),
              const Divider(),
            ],
          );
        }).toList(),
      ),
    );
  }

  // --- 도움 위젯: 정산 그리드 ---
  // 1. 4개의 데이터를 하나의 리스트로 묶는 메인 함수
  Widget _buildFinancialList(DailyReport r, NumberFormat f) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildFinanceRow("총 매출액", f.format(r.grandTotal), Colors.redAccent, isBold: true),
            const Divider(height: 24),
            _buildFinanceRow("카드 매출", f.format(r.cardSales), Colors.blue),
            const Divider(height: 24),
            _buildFinanceRow("현금 합계", f.format(r.cashFlow['현금'] ?? 0), Colors.green),
            const Divider(height: 24),
            _buildFinanceRow("현금 지출", f.format(r.cashFlow['현금지출'] ?? 0), Colors.orange),
          ],
        ),
      ),
    );
  }

// 2. 리스트의 한 줄을 구성하는 도우미 함수
  Widget _buildFinanceRow(String label, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[700],
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // --- 도움 위젯: 재고 표 ---
  Widget _buildInventoryTable(List<Map<String, dynamic>> log) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [DataColumn(label: Text('품목')), DataColumn(label: Text('시작')), DataColumn(label: Text('판매')), DataColumn(label: Text('실재')), DataColumn(label: Text('파지'))],
          rows: log.map((i) => DataRow(cells: [
            DataCell(Text(i['품목명'] ?? '-')), DataCell(Text(i['시작재고'] ?? '-')),
            DataCell(Text(i['판매'] ?? '-')), DataCell(Text(i['실재'] ?? '-')), DataCell(Text(i['파지'] ?? '-')),
          ])).toList(),
        ),
      ),
    );
  }

  // --- 도움 위젯: 지출 표 ---
  Widget _buildExpenseTable(List<Map<String, dynamic>> expenses, NumberFormat f) {
    return Card(
      child: Column(
        children: [
          const ListTile(title: Text("지출 내역", style: TextStyle(fontWeight: FontWeight.bold))),
          ...expenses.map((e) => ListTile(
            dense: true,
            title: Text(e['category'] ?? '일반지출'),
            subtitle: Text(e['note'] ?? ''),
            trailing: Text(f.format(e['amount'] ?? 0)),
          )).toList(),
          if (expenses.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text("지출 없음")),
        ],
      ),
    );
  }

  // --- 도움 위젯: 준비 및 유통기한 그리드 (에러 해결용 추가) ---
  Widget _buildIntegratedPrepSection(Map<String, double> prep, List<Map<String, dynamic>> expiry) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- [A] 오전 준비 섹션 (기존 유지) ---
            Row(
              children: [
                const Text("오전 준비 내역", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 6),
                Text("(${prep.length} 항목)", style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            if (prep.isEmpty)
              const Text("입력된 준비 내역이 없습니다.", style: TextStyle(color: Colors.grey, fontSize: 13))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: prep.entries.map((e) => _buildTag(e.key, e.value.toInt().toString(), brownbear)).toList(),
              ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Divider(),
            ),

            // --- [B] 유통기한 점검 섹션 (날짜 추가 수정) ---
            Row(
              children: [
                const Text("유통기한 점검 내역", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 6),
                Text("(${expiry.length})", style: const TextStyle(color: brownbear, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            if (expiry.isEmpty)
              const Text("점검된 품목이 없습니다.", style: TextStyle(color: Colors.grey, fontSize: 13))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: expiry.map((e) {
                  // 🚀 품목명 추출
                  String itemName = e['품목명'] ?? e['item'] ?? "미정";

                  // 🚀 날짜 데이터 추출 (DB 필드명이 'date' 또는 'expiryDate'라고 가정)
                  String expiryDate = e['date'] ?? e['expiryDate'] ?? "";

                  // 날짜가 있다면 "품목명(날짜)" 형식으로 표시하거나 태그의 value 자리에 넣습니다.
                  return _buildTag(itemName, expiryDate.isNotEmpty ? expiryDate : null, brownbear);
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // 공통 태그 UI 도우미
  Widget _buildTag(String label, String? value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        value != null ? "$label: $value" : label,
        style: TextStyle(color: color.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  // --- 도움 위젯: 메모 섹션 ---
  Widget _buildNoteSection(DailyReport r) {
    return Column(children: [
      _noteCard("오전 메모", r.morningNote),
      _noteCard("마감 메모", r.closingNote),
      _noteCard("인사/채용/퇴사", "채용: ${r.hiring}\n퇴사: ${r.leaving}"),
      _noteCard("기타 전달사항", "전달: ${r.transfer}\n선입금: ${r.preDeposit}"),
    ]);
  }

  // --- 서브 위젯들 ---
  Widget _dataBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _noteCard(String title, String content) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), subtitle: Text(content.isEmpty ? "내용 없음" : content)),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/daily_report_model.dart';
import '../../services/report_service.dart';
import 'widgets/report_detail_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecordsScreen extends StatefulWidget {
  final DateTime selectedDate;

  const RecordsScreen({super.key, required this.selectedDate});

  @override
  State<RecordsScreen> createState() => RecordsScreenState(); // GlobalKey 사용을 위해 공개
}

class RecordsScreenState extends State<RecordsScreen> {
  DailyReport? _report;
  bool _isLoading = false;
  final String _storeId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'ko_KR';
    fetchReport(widget.selectedDate); // 초기 로드
  }

  @override
  void didUpdateWidget(RecordsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      fetchReport(widget.selectedDate); // 날짜 변경 시 로드
    }
  }

  // 상단 박스 버튼이 직접 호출할 수 있도록 공개(Public)
  Future<void> fetchReport([DateTime? date]) async {
    final targetDate = date ?? widget.selectedDate;
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final report = await ReportService().getReport(targetDate, _storeId);
      if (mounted) {
        setState(() => _report = report);
      }
    } catch (e) {
      print("데이터 불러오기 실패: $e");
      if (mounted) setState(() => _report = null);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 매출 계산 Getters
  int get _daySales {
    if (_report == null || _report!.salesTime.isEmpty) return 0;
    return (_report!.salesTime['주간']?['갈비'] ?? 0) + (_report!.salesTime['주간']?['정육'] ?? 0);
  }

  int get _nightSales {
    if (_report == null || _report!.salesTime.isEmpty) return 0;
    return (_report!.salesTime['야간']?['갈비'] ?? 0) + (_report!.salesTime['야간']?['정육'] ?? 0);
  }

  int get _togoSales {
    if (_report == null || _report!.salesTime.isEmpty) return 0;
    return (_report!.salesTime['점심']?['포장'] ?? 0) + (_report!.salesTime['주간']?['포장'] ?? 0) + (_report!.salesTime['야간']?['포장'] ?? 0);
  }

  // 오전 보고 상세 팝업
  void _showMorningDetail() {
    if (_report == null) return;
    final morningContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailRow(label: '예약 현황', value: _report!.reservation),
        DetailRow(label: '특이사항', value: _report!.morningNote),
        const Padding(padding: EdgeInsets.only(top: 10, bottom: 5), child: Text('— 준비 수량', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87))),
        if (_report!.morningPrep.isEmpty) const DetailRow(label: '기록 없음', value: '-'),
        ..._report!.morningPrep.entries.map((entry) {
          final value = entry.value is num ? _formatCurrency(entry.value) : entry.value.toString();
          return DetailRow(label: entry.key, value: '${value}개');
        }).toList(),
        const Padding(padding: EdgeInsets.only(top: 10, bottom: 5), child: Text('— 유통기한', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87))),
        if (_report!.expiryLog.isEmpty) const DetailRow(label: '기록 없음', value: '-'),
        ..._report!.expiryLog.map((log) => DetailRow(label: log['item']?.toString() ?? '품명 누락', value: log['date']?.toString() ?? '날짜 누락')).toList(),
      ],
    );
    showDialog(context: context, builder: (context) => ReportDetailDialog(report: _report!, title: '오전 근무 보고', content: morningContent));
  }

  // 매출 보고 상세 팝업
  void _showSalesDetail() {
    if (_report == null) return;
    final Map<String, double> totalVolume = {};
    _report!.dayVolume?.forEach((k, v) => totalVolume[k] = v);
    _report!.nightVolume?.forEach((k, v) => totalVolume[k] = (totalVolume[k] ?? 0.0) + v);

    final salesContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailRow(label: '총 매출', value: '${_formatCurrency(_report!.grandTotal)}원'),
        const Padding(padding: EdgeInsets.only(top: 10, bottom: 5), child: Text('— 시간대별 매출', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87))),
        ..._report!.salesTime.entries.map((timeEntry) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 4, bottom: 2, left: 8), child: Text('${timeEntry.key} 소계', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))),
            ...timeEntry.value.entries.map((salesEntry) => DetailRow(label: ' • ${salesEntry.key}', value: '${_formatCurrency(salesEntry.value)}원')).toList(),
          ],
        )).toList(),
        const Padding(padding: EdgeInsets.only(top: 10, bottom: 5), child: Text('— 메뉴별 판매량', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87))),
        ...totalVolume.entries.map((ve) => DetailRow(label: ve.key, value: '${ve.value % 1 == 0 ? ve.value.toInt() : ve.value}개')).toList(),
      ],
    );
    showDialog(context: context, builder: (context) => ReportDetailDialog(report: _report!, title: '매출/정산 보고', content: salesContent));
  }

  // 마감 보고 상세 팝업
  void _showClosingDetail() {
    if (_report == null) return;
    final closingContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailRow(label: '책임자', value: _report!.author),
        DetailRow(label: '마감 특이사항', value: _report!.closingNote),
        const Padding(padding: EdgeInsets.only(top: 10, bottom: 5), child: Text('— 정산 내역', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87))),
        DetailRow(label: '총매출', value: '${_formatCurrency(_report!.grandTotal)}원'),
        DetailRow(label: '직원할인', value: '${_formatCurrency(_report!.cashFlow['직원할인'])}원'),
        DetailRow(label: '현금', value: '${_formatCurrency(_report!.cashFlow['현금'])}원'),
        DetailRow(label: '현금지출', value: '${_formatCurrency(_report!.cashFlow['현금지출'])}원'),
        DetailRow(label: '카드매출', value: '${_formatCurrency(_report!.cardSales)}원'),
        const Padding(padding: EdgeInsets.only(top: 10, bottom: 5), child: Text('— 지출 내역', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87))),
        if (_report!.expenseList.isEmpty) const DetailRow(label: '지출 없음', value: '-'),
        ..._report!.expenseList.map((e) => DetailRow(label: e['category']?.toString() ?? '미분류', value: '${_formatCurrency(e['amount'])}원')).toList(),
        const Padding(padding: EdgeInsets.only(top: 10, bottom: 5), child: Text('— 마감 재고', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87))),
        if (_report!.inventoryLog.isEmpty) const DetailRow(label: '재고 기록 없음', value: '-'),
        ..._report!.inventoryLog.map((l) => DetailRow(label: l['품목명']?.toString() ?? '알 수 없음', value: '${_formatCurrency(l['실재'])} ${l['unit'] ?? '개'}')).toList(),
      ],
    );
    showDialog(context: context, builder: (context) => ReportDetailDialog(report: _report!, title: '마감 정산 보고', content: closingContent));
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '0';
    try {
      if (value is num) return NumberFormat('#,###').format(value);
      return NumberFormat('#,###').format(num.parse(value.toString().replaceAll(',', '')));
    } catch (_) { return value.toString(); }
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, {VoidCallback? onDetailTap}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(top: 20, bottom: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.1), border: Border(left: BorderSide(color: color, width: 4))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [Icon(icon, size: 20, color: color), const SizedBox(width: 8), Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color))]),
          if (onDetailTap != null) TextButton(onPressed: onDetailTap, child: const Text('상세 보기', style: TextStyle(fontSize: 14, color: Colors.black54))),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    String displayValue = (value == null || value.toString().isEmpty) ? '-' : value.toString();
    if (label.contains('매출') || label.contains('현금') || label.contains('카드')) displayValue = "${_formatCurrency(value)}원";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          Expanded(child: Text(displayValue, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMorningData = _report?.morningNote.isNotEmpty == true || _report?.morningPrep.isNotEmpty == true;
    final hasSalesData = (_report?.grandTotal ?? 0) > 0;
    final hasClosingData = _report?.closingNote.isNotEmpty == true || _report?.inventoryLog.isNotEmpty == true;
    final hasAnyData = hasMorningData || hasSalesData || hasClosingData;

    return Container(
      color: Colors.white,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !hasAnyData
          ? Center(child: Text("${DateFormat('MM월 dd일').format(widget.selectedDate)} 데이터가 없습니다."))
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('🌞 오전 근무 보고', Icons.wb_sunny, Colors.orange, onDetailTap: hasMorningData ? _showMorningDetail : null),
            if (hasMorningData) ...[
              _buildInfoRow('예약 현황', _report!.reservation),
              _buildInfoRow('특이사항', _report!.morningNote),
              if (_report!.staffCounts.isNotEmpty) ...[
                _buildInfoRow('오전인원', '사장:${_report!.staffCounts['오전']?['사장'] ?? 0}, 정육:${_report!.staffCounts['오전']?['정육'] ?? 0}, 홀:${_report!.staffCounts['오전']?['홀'] ?? 0}, 주방:${_report!.staffCounts['오전']?['주방'] ?? 0}'),
                _buildInfoRow('오후인원', '사장:${_report!.staffCounts['오후']?['사장'] ?? 0}, 정육:${_report!.staffCounts['오후']?['정육'] ?? 0}, 홀:${_report!.staffCounts['오후']?['홀'] ?? 0}, 주방:${_report!.staffCounts['오후']?['주방'] ?? 0}'),
                _buildInfoRow('야간인원', '야간실장:${_report!.staffCounts['야간']?['야간실장'] ?? 0}, 정육:${_report!.staffCounts['야간']?['정육'] ?? 0}, 홀:${_report!.staffCounts['야간']?['홀'] ?? 0}, 주방:${_report!.staffCounts['야간']?['주방'] ?? 0}'),
              ],
            ],

            _buildSectionHeader('💰 매출 보고', Icons.attach_money, Colors.blue, onDetailTap: hasSalesData ? _showSalesDetail : null),
            if (hasSalesData) ...[
              _buildInfoRow('총매출', _daySales + _nightSales),
              _buildInfoRow('주간매출', _daySales),
              _buildInfoRow('야간매출', _nightSales),
              _buildInfoRow('포장총액', _togoSales),
            ],

            _buildSectionHeader('🌙 마감 보고', Icons.nights_stay, Colors.indigo, onDetailTap: hasClosingData ? _showClosingDetail : null),
            if (hasClosingData) ...[
              _buildInfoRow('마감 책임자', _report!.author),
              _buildInfoRow('총매출', _report!.grandTotal),
              _buildInfoRow('현금매출', _report!.cashFlow['총현금매출']),
              _buildInfoRow('카드매출', _report!.cardSales),
              _buildInfoRow('마감 특이사항', _report!.closingNote),
              _buildInfoRow('입사자', _report!.hiring),
              _buildInfoRow('퇴사자', _report!.leaving),
              _buildInfoRow('전입/전출', _report!.transfer),
              _buildInfoRow('선입금', _report!.preDeposit),
            ],
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
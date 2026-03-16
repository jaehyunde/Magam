import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/daily_report_model.dart';
import '../../services/report_service.dart';
import 'widgets/report_detail_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../report/tab_report.dart';
import '../../common/constants.dart'; // khakiMain을 가져오기 위해 필요

class RecordsScreen extends StatefulWidget {
  final DateTime selectedDate;
  final ReportPeriod period;

  const RecordsScreen({
    super.key,
    required this.selectedDate,
    required this.period,
  });

  @override
  State<RecordsScreen> createState() => RecordsScreenState();
}

class RecordsScreenState extends State<RecordsScreen> {
  DailyReport? _report;
  List<DailyReport> _reports = []; // 🚀 [해결] 누락되었던 리스트 선언
  bool _isLoading = false;
  final String _storeId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'ko_KR';
    fetchReport(widget.selectedDate);
  }

  @override
  void didUpdateWidget(RecordsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate || widget.period != oldWidget.period) {
      fetchReport(widget.selectedDate);
    }
  }

  Future<void> fetchReport([DateTime? date]) async {
    final targetDate = date ?? widget.selectedDate;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _report = null;
      _reports = [];
    });

    try {
      if (widget.period == ReportPeriod.day) {
        final report = await ReportService().getReport(targetDate, _storeId);
        if (mounted) setState(() => _report = report);
      } else {
        // 🚀 [참고] 나중에 쿼리함수 수정 후 여기서 호출하게 됩니다.
        DateTime start, end;
        if (widget.period == ReportPeriod.month) {
          start = DateTime(targetDate.year, targetDate.month, 1);
          end = DateTime(targetDate.year, targetDate.month + 1, 0);
        } else if (widget.period == ReportPeriod.year) {
          start = DateTime(targetDate.year, 1, 1);
          end = DateTime(targetDate.year, 12, 31);
        } else {
          start = DateTime(2024, 1, 1);
          end = DateTime.now();
        }

        final reports = await ReportService().getReportsByRange(_storeId, start, end);
        if (mounted) setState(() => _reports = reports);
      }
    } catch (e) {
      print("데이터 불러오기 실패: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 매출 계산 Getters (일간용)
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

  // 🚀 1. 오전 보고 상세 팝업 (오리지널 복구)
  void _showMorningDetail() {
    if (_report == null) return;

    final morningContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 인원 현황 (상세 내역 추가)
        _buildPopupSectionTitle('인원 현황'),
        if (_report!.staffCounts.isNotEmpty) ...[
          DetailRow(
            label: '오전 인원',
            value: '사장:${_report!.staffCounts['오전']?['사장'] ?? 0}, 정육:${_report!.staffCounts['오전']?['정육'] ?? 0}, 홀:${_report!.staffCounts['오전']?['홀'] ?? 0}, 주방:${_report!.staffCounts['오전']?['주방'] ?? 0}',
            labelWidth: 80, // 🚀 라벨 너비를 줄여서 뒤의 긴 텍스트 공간 확보
          ),
          DetailRow(
            label: '오후 인원',
            value: '사장:${_report!.staffCounts['오후']?['사장'] ?? 0}, 정육:${_report!.staffCounts['오후']?['정육'] ?? 0}, 홀:${_report!.staffCounts['오후']?['홀'] ?? 0}, 주방:${_report!.staffCounts['오후']?['주방'] ?? 0}',
            labelWidth: 80,
          ),
          DetailRow(
            label: '야간 인원',
            value: '야간실장:${_report!.staffCounts['야간']?['야간실장'] ?? 0}, 정육:${_report!.staffCounts['야간']?['정육'] ?? 0}, 홀:${_report!.staffCounts['야간']?['홀'] ?? 0}, 주방:${_report!.staffCounts['야간']?['주방'] ?? 0}',
            labelWidth: 80,
          ),
        ] else
          const DetailRow(label: '인원 정보', value: '기록 없음'),

        const Divider(height: 10),

        // 근무 현황
        _buildPopupSectionTitle('근무 현황'),
        DetailRow(label: '예약 현황', value: _report!.reservation.isEmpty ? '없음' : _report!.reservation),
        DetailRow(label: '오전 특이사항', value: _report!.morningNote.isEmpty ? '없음' : _report!.morningNote),

        const Divider(height: 10),

        // 4. 준비 수량 및 유통기한 (기존과 동일)
        _buildPopupSectionTitle('준비 수량 내역'),
        if (_report!.morningPrep.isEmpty)
          const DetailRow(label: '기록 없음', value: '-')
        else
          ..._report!.morningPrep.entries.map((entry) => DetailRow(
            label: ' • ${entry.key}',
            value: '${entry.value}개',
            labelWidth: 100,
          )).toList(),

        const Divider(height: 10),
        _buildPopupSectionTitle('유통기한 점검 리스트'),
        if (_report!.expiryLog.isEmpty)
          const DetailRow(label: '기록 없음', value: '-')
        else
          ..._report!.expiryLog.map((log) => DetailRow(
            label: ' • ${log['item'] ?? '품명 누락'}',
            value: log['date'] ?? '날짜 누락',
            labelWidth: 100,
          )).toList(),
      ],
    );

    showDialog(
        context: context,
        builder: (context) => ReportDetailDialog(
            report: _report!,
            title: '오전 근무 상세 보고',
            content: morningContent
        )
    );
  }

  // 매출 보고 상세 팝업 (오리지널 복구)
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
    showDialog(
        context: context,
        builder: (context) => ReportDetailDialog(report: _report!, title: '매출/정산 보고', content: salesContent)
    );
  }

  // 🚀 3. 마감 보고 상세 팝업 (오리지널 복구)
  // 🚀 [완결본] 마감 보고 상세 팝업 (모든 필드 출력)
  void _showClosingDetail() {
    if (_report == null) return;

    final closingContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 기본 정보 및 책임자
        _buildPopupSectionTitle('마감 정보'),
        DetailRow(label: '마감 책임자', value: _report!.author),
        DetailRow(label: '마감 시간', value: DateFormat('HH:mm').format(_report!.updatedAt ?? DateTime.now())),

        const Divider(),

        // 2. 정산 상세 (현금/카드/할인)
        _buildPopupSectionTitle('정산 상세 내역'),
        DetailRow(label: '총 매출액', value: '${_formatCurrency(_report!.grandTotal)}원'),
        DetailRow(label: '카드 매출', value: '${_formatCurrency(_report!.cardSales)}원'),
        DetailRow(label: '현금 매출', value: '${_formatCurrency(_report!.cashFlow['총현금매출'] ?? _report!.cashFlow['현금'])}원'),
        DetailRow(label: '직원 할인', value: '${_formatCurrency(_report!.cashFlow['직원할인'])}원'),
        DetailRow(label: '현금 지출', value: '${_formatCurrency(_report!.cashFlow['현금지출'])}원'),

        const Divider(),

        // 3. 인사 및 행정 (본부장님이 강조하신 부분!)
        _buildPopupSectionTitle('인사'),
        DetailRow(label: '입사자', value: _report!.hiring.isEmpty ? '-' : _report!.hiring),
        DetailRow(label: '퇴사자', value: _report!.leaving.isEmpty ? '-' : _report!.leaving),
        DetailRow(label: '전입/전출', value: _report!.transfer.isEmpty ? '-' : _report!.transfer),

        const Divider(),

        // 4. 지출 상세 리스트
        _buildPopupSectionTitle('지출 내역'),
        if (_report!.expenseList.isEmpty)
          const DetailRow(label: '기록 없음', value: '-')
        else
          ..._report!.expenseList.map((e) => DetailRow(
              label: ' • ${e['category']?.toString() ?? '미분류'}',
              value: '${_formatCurrency(e['amount'])}원'
          )),
        DetailRow(label: '선입금', value: _report!.preDeposit.isEmpty ? '-' : _report!.preDeposit),

        const Divider(),

        // 5. 마감 재고 상세
        _buildPopupSectionTitle('마감 재고 현황'),
        if (_report!.inventoryLog.isEmpty)
          const DetailRow(label: '기록 없음', value: '-')
        else
          ..._report!.inventoryLog.map((l) => DetailRow(
              label: ' • ${l['품목명']?.toString() ?? '알 수 없음'}',
              value: '${_formatCurrency(l['실재'])} ${l['unit'] ?? '개'}'
          )),

        const Divider(),

        // 6. 특이사항
        _buildPopupSectionTitle('마감 특이사항'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _report!.closingNote.isEmpty ? '특이사항 없음' : _report!.closingNote,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );

    showDialog(
        context: context,
        builder: (context) => ReportDetailDialog(
            report: _report!,
            title: '마감 정산 상세 보고',
            content: closingContent
        )
    );
  }

  // 🚀 팝업 내 섹션 타이틀을 위한 작은 헬퍼 위젯
  Widget _buildPopupSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 5),
      child: Text(
        '— $title',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.brown),
      ),
    );
  }



  String _formatCurrency(dynamic value) {
    if (value == null) return '0';
    try {
      if (value is num) return NumberFormat('#,###').format(value);
      return NumberFormat('#,###').format(num.parse(value.toString().replaceAll(',', '')));
    } catch (_) { return value.toString(); }
  }

  // 🚀 [해결] build 함수는 하나로 통합!
  @override
  Widget build(BuildContext context) {
    // 1. 현재 모드 확인
    final bool isDaily = widget.period == ReportPeriod.day;

    // 2. 데이터 존재 여부 체크
    // 하루 모드일 때는 _report가 있는지, 기간 모드일 때는 _reports 리스트가 비어있지 않은지 확인
    final bool hasData = isDaily ? (_report != null) : _reports.isNotEmpty;

    // 3. 하루 모드일 때 각 섹션별 데이터 유무 (본부장님 기존 로직)
    final hasMorningData = isDaily && (_report?.morningNote.isNotEmpty == true || _report?.morningPrep.isNotEmpty == true);
    final hasSalesData = isDaily && ((_report?.grandTotal ?? 0) > 0);
    final hasClosingData = isDaily && (_report?.closingNote.isNotEmpty == true || _report?.inventoryLog.isNotEmpty == true);

    // 하루 모드에서 아무 데이터도 없는지 확인
    final bool isDayEmpty = isDaily && !hasMorningData && !hasSalesData && !hasClosingData;

    return Container(
      color: Colors.white,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: khakiMain))
          : (isDaily ? isDayEmpty : !hasData) // 데이터가 정말 없는지 판단
          ? Center(child: Text("${_getFormattedPeriod()} 데이터가 없습니다."))
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------------------------------------------------
            // 🚀 [상황 1] 한달 / 일년 / 전체 모드
            // ---------------------------------------------------------
            if (!isDaily) ...[
              const SizedBox(height: 10),
              _buildAggregatedSummaryCard(),

              const SizedBox(height: 25),
              _buildSectionHeader(
                  widget.period == ReportPeriod.month ? '일별 매출 내역' :
                  widget.period == ReportPeriod.year ? '월별 매출 내역' : '연도별 매출 내역',
                  Icons.assessment_outlined,
                  khakiMain
              ),

              // 🚀 [핵심] 기간에 따른 그룹화 리스트 출력
              ..._buildGroupedList(),
            ],

            // ---------------------------------------------------------
            // 🚀 [상황 2] 하루 토글 클릭 시 -> 본부장님의 오리지널 상세 UI
            // ---------------------------------------------------------
            if (isDaily && _report != null) ...[
              // 1. 오전 근무 보고
              _buildSectionHeader('오전 근무 보고', Icons.wb_sunny, Colors.orange, onDetailTap: hasMorningData ? _showMorningDetail : null),
              if (hasMorningData) ...[
                _buildInfoRow('예약 현황', _report!.reservation),
                _buildInfoRow('특이사항', _report!.morningNote),
                if (_report!.staffCounts.isNotEmpty) ...[
                  _buildInfoRow('오전인원', '사장:${_report!.staffCounts['오전']?['사장'] ?? 0}, 정육:${_report!.staffCounts['오전']?['정육'] ?? 0}, 홀:${_report!.staffCounts['오전']?['홀'] ?? 0}, 주방:${_report!.staffCounts['오전']?['주방'] ?? 0}'),
                  _buildInfoRow('오후인원', '사장:${_report!.staffCounts['오후']?['사장'] ?? 0}, 정육:${_report!.staffCounts['오후']?['정육'] ?? 0}, 홀:${_report!.staffCounts['오후']?['홀'] ?? 0}, 주방:${_report!.staffCounts['오후']?['주방'] ?? 0}'),
                  _buildInfoRow('야간인원', '야간실장:${_report!.staffCounts['야간']?['야간실장'] ?? 0}, 정육:${_report!.staffCounts['야간']?['정육'] ?? 0}, 홀:${_report!.staffCounts['야간']?['홀'] ?? 0}, 주방:${_report!.staffCounts['야간']?['주방'] ?? 0}'),
                ],
              ],

              // 2. 매출 보고
              _buildSectionHeader('매출 보고', Icons.attach_money, Colors.blue, onDetailTap: hasSalesData ? _showSalesDetail : null),
              if (hasSalesData) ...[
                _buildInfoRow('총매출', _daySales + _nightSales),
                _buildInfoRow('주간매출', _daySales),
                _buildInfoRow('야간매출', _nightSales),
                _buildInfoRow('포장총액', _togoSales),
              ],

              // 3. 마감 보고
              _buildSectionHeader('마감 보고', Icons.nights_stay, Colors.indigo, onDetailTap: hasClosingData ? _showClosingDetail : null),
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
            ],
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedList() {
    if (widget.period == ReportPeriod.month) {
      // 1. 한달 모드: 일별로 나열
      return _reports.map((r) => _buildSalesListItem(
          DateFormat('MM.dd (E)', 'ko_KR').format(DateTime.parse(r.date)),
          r.grandTotal
      )).toList();

    } else if (widget.period == ReportPeriod.year) {
      // 2. 일년 모드: 월별로 합산 (1월~12월)
      Map<int, int> monthlyMap = {};
      for (var r in _reports) {
        int month = DateTime.parse(r.date).month;
        monthlyMap[month] = (monthlyMap[month] ?? 0) + r.grandTotal;
      }
      // 월 순서대로 정렬해서 출력
      var sortedMonths = monthlyMap.keys.toList()..sort((a, b) => b.compareTo(a)); // 최신월 우선
      return sortedMonths.map((m) => _buildSalesListItem(
          "${widget.selectedDate.year}년 ${m.toString().padLeft(2, '0')}월",
          monthlyMap[m]!
      )).toList();

    } else {
      // 3. 전체 모드: 연도별로 합산
      Map<int, int> yearlyMap = {};
      for (var r in _reports) {
        int year = DateTime.parse(r.date).year;
        yearlyMap[year] = (yearlyMap[year] ?? 0) + r.grandTotal;
      }
      var sortedYears = yearlyMap.keys.toList()..sort((a, b) => b.compareTo(a));
      return sortedYears.map((y) => _buildSalesListItem(
          "$y년 합계",
          yearlyMap[y]!
      )).toList();
    }
  }

// 🚀 공통 리스트 아이템 디자인
  Widget _buildSalesListItem(String title, int amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 15)),
          Text(
            "${_formatCurrency(amount)}원",
            style: const TextStyle(fontWeight: FontWeight.bold, color: khakiMain, fontSize: 17),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySalesItem(DailyReport report) {
    // 날짜 형식 예쁘게 변환 (예: 02.01 일)
    String dateKey = DateFormat('MM.dd (E)', 'ko_KR').format(DateTime.parse(report.date));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(dateKey, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
          Text(
            "${_formatCurrency(report.grandTotal)}원",
            style: const TextStyle(fontWeight: FontWeight.bold, color: khakiMain, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // 🚀 [해결] 누락되었던 헬퍼 함수들 추가
  Widget _buildAggregatedSummaryCard() {
    final int totalSales = _reports.fold(0, (sum, r) => sum + r.grandTotal);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: khakiMain,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Text("${_getPeriodLabel()} 총 매출 합계", style: const TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 15),
          Text("${_formatCurrency(totalSales)}원", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _getPeriodLabel() {
    if (widget.period == ReportPeriod.month) return "${widget.selectedDate.month}월";
    if (widget.period == ReportPeriod.year) return "${widget.selectedDate.year}년";
    return "전체";
  }

  String _getFormattedPeriod() {
    if (widget.period == ReportPeriod.day) return DateFormat('MM월 dd일').format(widget.selectedDate);
    return _getPeriodLabel();
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
    if (label.contains('매출') || label.contains('현금') || label.contains('카드') || label.contains('포장')) displayValue = "${_formatCurrency(value)}원";
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
}


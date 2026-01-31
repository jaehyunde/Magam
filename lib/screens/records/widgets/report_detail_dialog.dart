import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/daily_report_model.dart';

// 보고서 상세 정보를 표시할 팝업 위젯
class ReportDetailDialog extends StatelessWidget {
  final DailyReport report;
  final String title;
  final Widget content;

  const ReportDetailDialog({
    super.key,
    required this.report,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),

      title: Text(
        '${report.date} - $title 상세 기록',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),

      content: SingleChildScrollView(
        // content 영역에 상세 기록 위젯이 들어갑니다.
        child: content,
      ),

      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기', style: TextStyle(color: Colors.indigo)),
        ),
      ],
    );
  }
}

// 🚀 데이터 표시를 위한 헬퍼 위젯
class DetailRow extends StatelessWidget {
  final String label;
  final dynamic value;

  const DetailRow({super.key, required this.label, required this.value});

  String _formatCurrency(dynamic val) {
    if (val is num) {
      return NumberFormat('#,###').format(val);
    }
    return val.toString();
  }

  @override
  Widget build(BuildContext context) {
    String displayValue = (value == null || (value is String && value.isEmpty)) ? '-' : value.toString();

    // 금액 관련 필드는 포맷팅
    if (label.contains('매출') || label.contains('지출') || label.contains('총액') || label.contains('금액')) {
      if (value is num) {
        displayValue = "${_formatCurrency(value)}원";
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(displayValue, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }
}

// 🚀 Map 데이터를 목록으로 표시하는 헬퍼 위젯
class MapDetailList extends StatelessWidget {
  final String listTitle;
  final Map<String, dynamic> data;

  const MapDetailList({super.key, required this.listTitle, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return Container();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 5),
          child: Text(
            '— $listTitle',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
          ),
        ),
        ...data.entries.map((entry) {
          // Map의 값이 Map인 경우 (예: salesTime의 day/night)는 재귀적으로 처리
          if (entry.value is Map) {
            return MapDetailList(
                listTitle: entry.key,
                data: entry.value as Map<String, dynamic>
            );
          }
          return DetailRow(label: entry.key, value: entry.value);
        }).toList(),
        const Divider(),
      ],
    );
  }
}
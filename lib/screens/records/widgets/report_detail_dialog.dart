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
        title,
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
  final double fontSize;
  final double verticalPadding;
  final double labelWidth; // 🚀 1. 변수를 선언했습니다.

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.fontSize = 15.0, // 🚀 기본 글씨를 12로 낮췄습니다.
    this.verticalPadding = 2.0, // 🚀 기본 간격을 촘촘하게 2로 낮췄습니다.
    this.labelWidth = 120.0, // 🚀 2. 생성자에도 기본값을 넣었습니다.
  });

  String _formatCurrency(dynamic val) {
    if (val is num) {
      return NumberFormat('#,###').format(val);
    }
    return val.toString();
  }

  @override
  Widget build(BuildContext context) {
    String displayValue = (value == null || (value is String && value.isEmpty)) ? '-' : value.toString();

    // 금액 관련 필드 포맷팅
    if (label.contains('매출') || label.contains('지출') || label.contains('총액') || label.contains('금액')) {
      if (value is num) {
        displayValue = "${_formatCurrency(value)}원";
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: labelWidth, // 🚀 이제 여기서 에러가 나지 않습니다!
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                displayValue,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: fontSize,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
          ),
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
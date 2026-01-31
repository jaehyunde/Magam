// lib/models/daily_report_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DailyReport {
  // 1. 기본 정보
  final String id;
  final String date;
  final String storeId;
  final String author;
  final String status;

  // 2. 오전 보고
  final Map<String, dynamic> staffCounts;
  final Map<String, dynamic> qualityCheck;
  final String reservation;
  final String morningNote;
  final Map<String, double> morningPrep;
  final List<Map<String, dynamic>> expiryLog;

  // 3. 매출 보고
  // 🚀 [수정] 중첩 Map 구조를 담기 위해 dynamic 유지. (tab_sales.dart에서 Map<String, Map<String, int>>로 사용)
  final Map<String, dynamic> salesTime;
  // 🚀 [수정] 결제 정보를 담기 위해 dynamic 유지. (tab_closing.dart에서 Map<String, int>로 사용)
  final Map<String, dynamic> salesCategory;
  final Map<String, dynamic> salesVolume;
  // 🚀 [수정] Double 타입으로 명시
  final Map<String, double>? dayVolume;
  final Map<String, double>? nightVolume;

  // 4. 정산 및 재무
  final int grandTotal;
  final int cardSales;
  final Map<String, dynamic> cashFlow;
  final List<Map<String, dynamic>> expenseList;
  final List<Map<String, dynamic>> inventoryLog; // tab_closing.dart에서 String 값도 포함하므로 dynamic 유지

  // 5. 기타 정보
  final String closingNote;
  final String hiring;
  final String leaving;
  final String transfer;
  final String preDeposit;

  DailyReport({
    required this.id,
    required this.date,
    required this.storeId,
    required this.author,
    required this.status,
    required this.staffCounts,
    required this.qualityCheck,
    required this.reservation,
    required this.morningNote,
    required this.morningPrep,
    required this.expiryLog,
    required this.salesTime,
    required this.salesCategory,
    required this.salesVolume,
    this.dayVolume,
    this.nightVolume,
    required this.grandTotal,
    required this.cardSales,
    required this.cashFlow,
    required this.expenseList,
    required this.inventoryLog,
    required this.closingNote,
    required this.hiring,
    required this.leaving,
    required this.transfer,
    required this.preDeposit,
  });

  // Firestore에서 데이터를 불러올 때 쓰는 함수 (From JSON)
  factory DailyReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) throw Exception("데이터가 비어있습니다.");

    // 🚀 [추가] 안전한 숫자 변환 헬퍼
    int toInt(dynamic v) => (v is num) ? v.toInt() : 0;
    double toDouble(dynamic v) => (v is num) ? v.toDouble() : 0.0;

    // 🚀 [추가] 안전한 Map 변환 헬퍼
    Map<String, double> loadDoubleMap(dynamic source) {
      if (source == null || source is! Map) return {};
      return Map<String, dynamic>.from(source).map(
              (key, value) => MapEntry(key.toString(), toDouble(value)));
    }

    return DailyReport(
      id: doc.id,
      date: data['date'] ?? '',
      storeId: data['storeId'] ?? '',
      author: data['author'] ?? '',
      status: data['status'] ?? 'writing',

      staffCounts: Map<String, dynamic>.from(data['staffCounts'] ?? {}),
      qualityCheck: Map<String, dynamic>.from(data['qualityCheck'] ?? {}),
      reservation: data['reservation'] ?? '',
      morningNote: data['morningNote'] ?? '',
      morningPrep: loadDoubleMap(data['morningPrep']),
      expiryLog: List<Map<String, dynamic>>.from(data['expiryLog'] ?? []),

      salesTime: Map<String, dynamic>.from(data['salesTime'] ?? {}),
      salesCategory: Map<String, dynamic>.from(data['salesCategory'] ?? {}),
      salesVolume: Map<String, dynamic>.from(data['salesVolume'] ?? {}),
      dayVolume: loadDoubleMap(data['dayVolume']),
      nightVolume: loadDoubleMap(data['nightVolume']),

      // 🚀 [수정] 'as int' 대신 'toInt()' 사용 (에러 방지 핵심)
      grandTotal: toInt(data['grandTotal']),
      cardSales: toInt(data['cardSales']),
      cashFlow: Map<String, dynamic>.from(data['cashFlow'] ?? {}),
      expenseList: List<Map<String, dynamic>>.from(data['expenseList'] ?? []),
      inventoryLog: List<Map<String, dynamic>>.from(data['inventoryLog'] ?? []),

      closingNote: data['closingNote'] ?? '',
      hiring: data['hiring'] ?? '',
      leaving: data['leaving'] ?? '',
      transfer: data['transfer'] ?? '',
      preDeposit: data['preDeposit'] ?? '',
    );
  }

  // Firestore에 데이터를 저장할 때 쓰는 함수 (To JSON)
  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'storeId': storeId,
      'author': author,
      'status': status,

      'staffCounts': staffCounts,
      'qualityCheck': qualityCheck,
      'reservation': reservation,
      'morningNote': morningNote,
      'morningPrep': morningPrep,
      'expiryLog': expiryLog,

      'salesTime': salesTime,
      'salesCategory': salesCategory,
      'salesVolume': salesVolume,
      'dayVolume': dayVolume,
      'nightVolume': nightVolume,

      'grandTotal': grandTotal,
      'cardSales': cardSales,
      'cashFlow': cashFlow,
      'expenseList': expenseList,
      'inventoryLog': inventoryLog,

      'closingNote': closingNote,
      'hiring': hiring,
      'leaving': leaving,
      'transfer': transfer,
      'preDeposit': preDeposit,
    };
  }
}
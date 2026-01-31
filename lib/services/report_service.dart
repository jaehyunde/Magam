import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/daily_report_model.dart';
import '../common/constants.dart';

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 헬퍼: 매장별 보고서 서브컬렉션 참조 경로
  CollectionReference _getReportsCollection(String storeId) {
    return _db.collection('stores').doc(storeId).collection('dailyReports');
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // lib/services/report_service.dart

  Future<Map<String, dynamic>> getAdminDashboardData(DateTime date) async {
    String dateStr = DateFormat('yyyy-MM-dd').format(date);
    print("🚩 1. 데이터 로드 시작 - 날짜: $dateStr"); // 로그 1

    List<Map<String, dynamic>> storeList = [];
    Map<String, dynamic> salesMap = {};
    Map<String, String> statusMap = {};

    try {
      var usersSnapshot = await _db.collection('users')
          .where('role', isNotEqualTo: 'admin')
          .get();

      print("🚩 2. 검색된 매장 유저 수: ${usersSnapshot.docs.length}"); // 로그 2

      for (var userDoc in usersSnapshot.docs) {
        String uid = userDoc.id;
        final userData = userDoc.data();
        String storeCode = userData['storeId'] ?? "unknown";

        print("🚩 3. 매장 확인: UID($uid), 코드($storeCode)"); // 로그 3

        storeList.add({
          'uid': uid,
          'storeCode': storeCode,
        });

        // 보고서 가져오기
        var reportDoc = await _db.collection('stores')
            .doc(uid)
            .collection('dailyReports')
            .doc(dateStr)
            .get();

        if (reportDoc.exists) {
          final rData = reportDoc.data() as Map<String, dynamic>;
          print("🚩 4. 보고서 발견! - UID($uid)");

          // 🚀 [수정 포인트] 수량(Volume)이 아닌 salesTime(금액)에서 합산합니다.

          // 내부 도우미: 맵 안의 숫자들을 모두 더하는 로직
          int sumOfMap(dynamic map) {
            if (map == null || map is! Map) return 0;
            int sum = 0;
            map.forEach((k, v) => sum += (v is num) ? v.toInt() : 0);
            return sum;
          }

          final salesTime = rData['salesTime'] as Map<String, dynamic>? ?? {};

          // 1. 오전 매출 = '점심' + '주간' 맵의 금액 합계
          int morningSum = sumOfMap(salesTime['주간']);

          // 2. 야간 매출 = '야간' 맵의 금액 합계
          int nightSum = sumOfMap(salesTime['야간']);

          // 3. 총 매출 = DB의 grandTotal 우선, 없으면 합산
          int totalSum = (rData['grandTotal'] is num)
              ? (rData['grandTotal'] as num).toInt()
              : (morningSum + nightSum);

          salesMap[uid] = {
            'morning': morningSum,
            'night': nightSum,
            'total': totalSum,
          };
          statusMap[uid] = rData['status'] ?? "writing";
          print("🚩 5. 매출 계산 완료: ${salesMap[uid]['total']}원 (오전:$morningSum, 야간:$nightSum)");
        } else {
          print("🚩 4-X. 보고서 없음: UID($uid), 날짜($dateStr)"); // 로그 4-X
          salesMap[uid] = {'morning': 0, 'night': 0, 'total': 0};
          statusMap[uid] = "";
        }
      }
      return {'stores': storeList, 'sales': salesMap, 'status': statusMap};
    } catch (e) {
      print("❌ 치명적 에러 발생: $e");
      return {'stores': [], 'sales': {}, 'status': {}};
    }
  }

  // ------------------------------------------------------------------------
  // 🌞 1. 오전 보고 저장 (DayTab)
  // ------------------------------------------------------------------------
  Future<void> saveMorningReport({
    required String date,
    required String storeId,
    required Map<String, dynamic> staffCounts,
    required String reservation,
    required String morningNote,
    required Map<String, dynamic> morningPrep,
    required List<Map<String, dynamic>> expiryLog,
  }) async {
    final collectionRef = _getReportsCollection(storeId);
    final Map<String, dynamic> data = {
      'date': date,
      'storeId': storeId,
      'status': 'writing', // 오전 보고 저장 시 상태 시작
      'staffCounts': staffCounts,
      'reservation': reservation,
      'morningNote': morningNote,
      'morningPrep': morningPrep,
      'expiryLog': expiryLog,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    await collectionRef.doc(date).set(data, SetOptions(merge: true));
  }

  // ------------------------------------------------------------------------
  // 💰 2. 매출 보고 저장 (SalesTab)
  // ------------------------------------------------------------------------
  Future<void> saveSalesReport({
    required String date,
    required String storeId,
    required Map<String, dynamic> salesTime,
    required Map<String, double> dayVolume,
    required Map<String, double> nightVolume,
    String status = 'writing', // 매개변수 활용
  }) async {
    final collectionRef = _getReportsCollection(storeId);
    final Map<String, dynamic> data = {
      'date': date,
      'storeId': storeId,
      'status': status, // 🚀 고정된 문자열이 아닌 넘겨받은 변수 사용
      'salesTime': salesTime,
      'dayVolume': dayVolume,
      'nightVolume': nightVolume,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    await collectionRef.doc(date).set(data, SetOptions(merge: true));
  }

  // ------------------------------------------------------------------------
  // 🌙 3. 마감 보고 저장 (ClosingTab)
  // ------------------------------------------------------------------------
  Future<void> saveClosingReport({
    required String date,
    required String storeId,
    required String author,
    required int grandTotal,
    required int cardSales,
    required Map<String, dynamic> cashFlow,
    required List<Map<String, dynamic>> expenseList,
    required List<Map<String, dynamic>> inventoryLog,
    required String closingNote,
    required String hiring,
    required String leaving,
    required String transfer,
    required String preDeposit,
    String status = 'complete', // 매개변수 활용
  }) async {
    final collectionRef = _getReportsCollection(storeId);
    final Map<String, dynamic> data = {
      'date': date,
      'storeId': storeId,
      'author': author,
      'status': status, // 🚀 고정된 문자열이 아닌 넘겨받은 변수 사용
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
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    await collectionRef.doc(date).set(data, SetOptions(merge: true));
  }

  // ------------------------------------------------------------------------
  // 🔍 4. 일일 보고서 개별 조회
  // ------------------------------------------------------------------------
  Future<DailyReport?> getReport(DateTime date, String storeId) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final collectionRef = _getReportsCollection(storeId);
    try {
      final doc = await collectionRef.doc(dateStr).get();
      if (doc.exists) return DailyReport.fromFirestore(doc);
      return null;
    } catch (e) {
      print('Failed to get report for $dateStr: $e');
      return null;
    }
  }

  // ------------------------------------------------------------------------
  // 🏪 5. 모든 매장 목록 가져오기 (Admin용)
  // ------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getAllStores() async {
    try {
      var snapshot = await _db.collection('users')
          .where('role', isNotEqualTo: 'admin')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final String storeCode = data['storeId'] ?? 'unknown';

        return {
          'id': doc.id,   // 신규 코드용
          'uid': doc.id,  // 구형 UI 코드용 (에러 방지 핵심)
          'storeId': storeCode,
          'name': kStoreNames[storeCode] ?? storeCode,
        };
      }).toList();
    } catch (e) {
      print('❌ 매장 목록 로드 실패: $e');
      return [];
    }
  }

  // 🚀 [수정] 'reports'라는 엉뚱한 컬렉션 대신 각 매장의 서브컬렉션을 훑도록 변경
  Future<Map<String, dynamic>> getAllStoreSummary(DateTime date) async {
    final stores = await getAllStores();
    Map<String, dynamic> summaries = {};
    String dateStr = DateFormat('yyyy-MM-dd').format(date);

    for (var store in stores) {
      String uid = store['id'];
      var doc = await _db.collection('stores').doc(uid).collection('dailyReports').doc(dateStr).get();
      if (doc.exists) {
        summaries[uid] = doc.data();
      }
    }
    return summaries;
  }

  Future<Map<String, String>> getAllStoresStatus(DateTime date) async {
    String dateStr = DateFormat('yyyy-MM-dd').format(date);
    Map<String, String> statusMap = {};

    try {
      final stores = await getAllStores();
      for (var store in stores) {
        String uid = store['id'].toString();
        var doc = await _db.collection('stores').doc(uid).collection('dailyReports').doc(dateStr).get();

        if (doc.exists) {
          // 🚀 [수정] DB의 상태값을 소문자로 변환하여 리턴 (UI 배지 로직과 일치시킴)
          String status = (doc.data()?['status'] ?? 'writing').toString().toLowerCase();
          statusMap[uid] = status;
        } else {
          statusMap[uid] = ""; // 작성 전
        }
      }
    } catch (e) {
      print("❌ 상태 로드 에러: $e");
    }
    return statusMap;
  }

  // ------------------------------------------------------------------------
  // 📊 7. 기타 유틸리티 함수들
  // ------------------------------------------------------------------------

  // 특정 매장의 과거 30일 기록
  Future<List<DailyReport>> getStoreReportHistory(String storeId) async {
    try {
      final snapshot = await _getReportsCollection(storeId)
          .orderBy(FieldPath.documentId, descending: true)
          .limit(30)
          .get();
      return snapshot.docs.map((doc) => DailyReport.fromFirestore(doc)).toList();
    } catch (e) {
      print('매장 기록 이력 로드 실패: $e');
      return [];
    }
  }

  // 매장 설정 저장/불러오기
  Future<void> saveStoreConfig(String uid, Map<String, dynamic> config) async {
    await _db.collection('users').doc(uid).set({'config': config}, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getStoreConfig(String storeUid) async {
    try {
      var doc = await _db.collection('users').doc(storeUid).get();
      if (doc.exists && doc.data()!['config'] != null) {
        return Map<String, dynamic>.from(doc.data()!['config']);
      }
    } catch (e) { print("Config 로드 에러: $e"); }
    return null;
  }

  Future<Map<String, dynamic>> getAllSalesData(DateTime date) async {
    try {
      // 날짜를 문자열로 변환 (예: 2024-05-20)
      String dateStr = DateFormat('yyyy-MM-dd').format(date);

      // 해당 날짜의 모든 매장 보고서를 가져옵니다.
      QuerySnapshot querySnapshot = await _firestore
          .collection('reports')
          .where('date', isEqualTo: dateStr)
          .get();

      Map<String, dynamic> allSales = {};

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        String storeId = data['storeId'] ?? "";

        // 매장별 매출 데이터를 정리해서 담습니다.
        allSales[storeId] = {
          'morning': data['morningSales'] ?? 0,
          'night': data['nightSales'] ?? 0,
          'total': (data['morningSales'] ?? 0) + (data['nightSales'] ?? 0),
        };
      }
      return allSales;
    } catch (e) {
      print("매출 데이터 로드 에러: $e");
      return {};
    }
  }

  Future<Map<String, int>> getMonthlyStoreTotals(DateTime selectedDate) async {
    // 1. 해당 월의 시작일(1일)과 종료일(선택일) 설정
    DateTime firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    String startStr = DateFormat('yyyy-MM-dd').format(firstDayOfMonth);
    String endStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    Map<String, int> monthlyTotals = {};

    try {
      // 🚀 collectionGroup을 사용하여 모든 매장의 'dailyReports' 서브컬렉션을 한 번에 조회합니다.
      // 주의: Firestore 콘솔에서 해당 쿼리에 대한 색인(Index) 생성이 필요할 수 있습니다.
      QuerySnapshot querySnapshot = await _db
          .collectionGroup('dailyReports')
          .where('date', isGreaterThanOrEqualTo: startStr)
          .where('date', isLessThanOrEqualTo: endStr)
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        String storeId = data['storeId'] ?? "";
        int grandTotal = (data['grandTotal'] is num) ? (data['grandTotal'] as num).toInt() : 0;

        if (storeId.isNotEmpty) {
          monthlyTotals[storeId] = (monthlyTotals[storeId] ?? 0) + grandTotal;
        }
      }
    } catch (e) {
      print('❌ 월 누계 로드 실패: $e');
    }
    return monthlyTotals;
  }

  // 🚀 [추가] 차트용 기간 데이터 로드 (시작일~종료일)
  Future<List<Map<String, dynamic>>> getSalesDataForRange({
    required DateTime start,
    required DateTime end,
    String? storeId,
  }) async {
    String startStr = DateFormat('yyyy-MM-dd').format(start);
    String endStr = DateFormat('yyyy-MM-dd').format(end);

    try {
      // 💡 여기서 _db는 클래스 상단에 이미 정의되어 있어야 합니다.
      Query query = _db.collectionGroup('dailyReports')
          .where('date', isGreaterThanOrEqualTo: startStr)
          .where('date', isLessThanOrEqualTo: endStr);

      if (storeId != null && storeId != "all") {
        query = query.where('storeId', isEqualTo: storeId);
      }

      QuerySnapshot snapshot = await query.get();

      var docs = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      docs.sort((a, b) => a['date'].compareTo(b['date']));

      return docs;
    } catch (e) {
      print("❌ 차트 데이터 로드 실패: $e");
      return [];
    }
  }
}
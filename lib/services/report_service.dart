import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/daily_report_model.dart';
import '../common/constants.dart';

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static bool forceRefresh = false;

  // 헬퍼: 매장별 보고서 서브컬렉션 참조 경로 (원본 유지)
  CollectionReference _getReportsCollection(String storeId) {
    return _db.collection('stores').doc(storeId).collection('dailyReports');
  }

  // 🚀 [추가] AdminDashboard에서 '수정 허용' 버튼 클릭 시 호출되는 함수
  Future<void> updateReportStatus(String date, String storeId, String status) async {
    try {
      await _getReportsCollection(storeId).doc(date).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(), // 수정 시간 기록
      });
    } catch (e) {
      print("❌ 상태 업데이트 실패: $e");
      throw e;
    }
  }

  Future<Map<String, dynamic>> getAdminDashboardData(DateTime date) async {
    String dateStr = DateFormat('yyyy-MM-dd').format(date);
    List<Map<String, dynamic>> storeList = [];
    Map<String, dynamic> salesMap = {};
    Map<String, String> statusMap = {};

    try {
      var usersSnapshot = await _db.collection('users')
          .where('role', isNotEqualTo: 'admin')
          .get();

      for (var userDoc in usersSnapshot.docs) {
        String uid = userDoc.id;
        final userData = userDoc.data();
        String storeCode = userData['storeId'] ?? "unknown";

        storeList.add({
          'uid': uid,
          'storeCode': storeCode,
        });

        var reportDoc = await _db.collection('stores')
            .doc(uid)
            .collection('dailyReports')
            .doc(dateStr)
            .get();

        if (reportDoc.exists) {
          final rData = reportDoc.data() as Map<String, dynamic>;
          int sumOfMap(dynamic map) {
            if (map == null || map is! Map) return 0;
            int sum = 0;
            map.forEach((k, v) => sum += (v is num) ? v.toInt() : 0);
            return sum;
          }
          final salesTime = rData['salesTime'] as Map<String, dynamic>? ?? {};
          int morningSum = sumOfMap(salesTime['주간']);
          int nightSum = sumOfMap(salesTime['야간']);
          int totalSum = (rData['grandTotal'] is num)
              ? (rData['grandTotal'] as num).toInt()
              : (morningSum + nightSum);

          salesMap[uid] = { 'morning': morningSum, 'night': nightSum, 'total': totalSum };
          statusMap[uid] = rData['status'] ?? "writing";
        } else {
          salesMap[uid] = {'morning': 0, 'night': 0, 'total': 0};
          statusMap[uid] = "";
        }
      }
      return {'stores': storeList, 'sales': salesMap, 'status': statusMap};
    } catch (e) {
      return {'stores': [], 'sales': {}, 'status': {}};
    }
  }

  // 🌞 1. 오전 보고 저장 (수정: 시간 추적 로직 추가)
  Future<void> saveMorningReport({
    required String date,
    required String storeId,
    required Map<String, dynamic> staffCounts,
    required String reservation,
    required String morningNote,
    required Map<String, dynamic> morningPrep,
    required List<Map<String, dynamic>> expiryLog,
  }) async {
    final docRef = _getReportsCollection(storeId).doc(date);
    final doc = await docRef.get();

    final Map<String, dynamic> data = {
      'date': date,
      'storeId': storeId,
      'status': 'writing',
      'staffCounts': staffCounts,
      'reservation': reservation,
      'morningNote': morningNote,
      'morningPrep': morningPrep,
      'expiryLog': expiryLog,
      'updatedAt': FieldValue.serverTimestamp(), // 🚀 통일된 시간 필드
    };
    if (!doc.exists) data['createdAt'] = FieldValue.serverTimestamp(); // 🚀 최초 생성 시간

    await docRef.set(data, SetOptions(merge: true));
  }

  // 💰 2. 매출 보고 저장 (수정: 시간 추적 로직 추가)
  Future<void> saveSalesReport({
    required String date,
    required String storeId,
    required Map<String, dynamic> salesTime,
    required Map<String, double> dayVolume,
    required Map<String, double> nightVolume,
    String status = 'writing',
  }) async {
    final docRef = _getReportsCollection(storeId).doc(date);
    final doc = await docRef.get();

    final Map<String, dynamic> data = {
      'date': date,
      'storeId': storeId,
      'status': status,
      'salesTime': salesTime,
      'dayVolume': dayVolume,
      'nightVolume': nightVolume,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!doc.exists) data['createdAt'] = FieldValue.serverTimestamp();

    await docRef.set(data, SetOptions(merge: true));
  }

  // 🌙 3. 마감 보고 저장 (수정: 시간 추적 로직 추가)
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
    String status = 'complete',
  }) async {
    final docRef = _getReportsCollection(storeId).doc(date);
    final doc = await docRef.get();

    final Map<String, dynamic> data = {
      'date': date,
      'storeId': storeId,
      'author': author,
      'status': status,
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
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!doc.exists) data['createdAt'] = FieldValue.serverTimestamp();

    await docRef.set(data, SetOptions(merge: true));
  }

  Future<DailyReport?> getReport(DateTime date, String storeId) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    try {
      final doc = await _getReportsCollection(storeId).doc(dateStr).get();
      if (doc.exists) return DailyReport.fromFirestore(doc);
      return null;
    } catch (e) { return null; }
  }

  Future<List<Map<String, dynamic>>> getAllStores() async {
    try {
      var snapshot = await _db.collection('users').where('role', isNotEqualTo: 'admin').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final String storeCode = data['storeId'] ?? 'unknown';
        return { 'id': doc.id, 'uid': doc.id, 'storeId': storeCode, 'name': kStoreNames[storeCode] ?? storeCode, };
      }).toList();
    } catch (e) { return []; }
  }

  Future<Map<String, dynamic>> getAllStoreSummary(DateTime date) async {
    final stores = await getAllStores();
    Map<String, dynamic> summaries = {};
    String dateStr = DateFormat('yyyy-MM-dd').format(date);
    for (var store in stores) {
      String uid = store['id'];
      var doc = await _db.collection('stores').doc(uid).collection('dailyReports').doc(dateStr).get();
      if (doc.exists) summaries[uid] = doc.data();
    }
    return summaries;
  }

  // 🚀 [수정] 타입 에러(Object vs Map) 해결
  Future<Map<String, String>> getAllStoresStatus(DateTime date) async {
    String dateStr = DateFormat('yyyy-MM-dd').format(date);
    Map<String, String> statusMap = {};
    try {
      final stores = await getAllStores();
      for (var store in stores) {
        String uid = store['id'].toString();
        var doc = await _db.collection('stores').doc(uid).collection('dailyReports').doc(dateStr).get();
        if (doc.exists) {
          // 💡 doc.data()를 Map으로 명시적으로 캐스팅하여 에러를 방지합니다.
          final data = doc.data() as Map<String, dynamic>?;
          String status = (data?['status'] ?? 'writing').toString().toLowerCase();
          statusMap[uid] = status;
        } else { statusMap[uid] = ""; }
      }
    } catch (e) { print("❌ 상태 로드 에러: $e"); }
    return statusMap;
  }

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
      String dateStr = DateFormat('yyyy-MM-dd').format(date);
      QuerySnapshot querySnapshot = await _firestore.collection('reports').where('date', isEqualTo: dateStr).get();
      Map<String, dynamic> allSales = {};
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        String storeId = data['storeId'] ?? "";
        allSales[storeId] = {
          'morning': data['morningSales'] ?? 0,
          'night': data['nightSales'] ?? 0,
          'total': (data['morningSales'] ?? 0) + (data['nightSales'] ?? 0),
        };
      }
      return allSales;
    } catch (e) { return {}; }
  }

  Future<Map<String, int>> getMonthlyStoreTotals(DateTime selectedDate) async {
    DateTime firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    String startStr = DateFormat('yyyy-MM-dd').format(firstDayOfMonth);
    String endStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    Map<String, int> monthlyTotals = {};
    try {
      QuerySnapshot querySnapshot = await _db.collectionGroup('dailyReports')
          .where('date', isGreaterThanOrEqualTo: startStr)
          .where('date', isLessThanOrEqualTo: endStr).get();
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        String storeId = data['storeId'] ?? "";
        int grandTotal = (data['grandTotal'] is num) ? (data['grandTotal'] as num).toInt() : 0;
        if (storeId.isNotEmpty) monthlyTotals[storeId] = (monthlyTotals[storeId] ?? 0) + grandTotal;
      }
    } catch (e) { print('❌ 월 누계 로드 실패: $e'); }
    return monthlyTotals;
  }

  Future<List<Map<String, dynamic>>> getSalesDataForRange({ required DateTime start, required DateTime end, String? storeId, }) async {
    String startStr = DateFormat('yyyy-MM-dd').format(start);
    String endStr = DateFormat('yyyy-MM-dd').format(end);
    try {
      Query query = _db.collectionGroup('dailyReports').where('date', isGreaterThanOrEqualTo: startStr).where('date', isLessThanOrEqualTo: endStr);
      if (storeId != null && storeId != "all") query = query.where('storeId', isEqualTo: storeId);
      QuerySnapshot snapshot = await query.get();
      var docs = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      docs.sort((a, b) => a['date'].compareTo(b['date']));
      return docs;
    } catch (e) { return []; }
  }

  Future<List<DailyReport>> getStoreReportHistory(String storeId) async {
    try {
      final snapshot = await _getReportsCollection(storeId).orderBy(FieldPath.documentId, descending: true).limit(30).get();
      return snapshot.docs.map((doc) => DailyReport.fromFirestore(doc)).toList();
    } catch (e) { return []; }
  }

  // 🚀 [최종 완결본] 기간별 리포트 조회 함수
  Future<List<DailyReport>> getReportsByRange(String storeId, DateTime start, DateTime end) async {
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);

    try {
      // 🚀 1. 경로 수정: 본부장님이 만드신 _getReportsCollection(storeId)를 사용합니다.
      final snapshot = await _getReportsCollection(storeId)
          .where('date', isGreaterThanOrEqualTo: startStr)
          .where('date', isLessThanOrEqualTo: endStr)
          .orderBy('date', descending: true)
          .get();

      // 🚀 2. 생성자 수정: 이미 파일 내에서 사용 중인 'fromFirestore'를 호출합니다.
      // 🚀 3. 타입 지정: map<DailyReport>를 통해 리스트 타입을 정확히 맞춥니다.
      return snapshot.docs.map<DailyReport>((doc) {
        return DailyReport.fromFirestore(doc); // 👈 doc.data()가 아닌 doc을 통째로 넘깁니다.
      }).toList();

    } catch (e) {
      print("❌ 기간 데이터 로드 중 에러 발생: $e");
      return [];
    }
  }
}
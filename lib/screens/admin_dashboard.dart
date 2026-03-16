// lib/screens/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/report_service.dart';
import '../models/daily_report_model.dart';
import '../common/constants.dart';
import 'records/widgets/admin_sales_tab.dart';
import 'records/widgets/admin_records_tab.dart';
import 'records/widgets/report_detail_dialog.dart';
import 'admin/store_config_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../services/biometric_helper.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<Map<String, dynamic>> _stores = [];
  Map<String, DailyReport?> _reports = {};
  Map<String, String> _storeStatuses = {};
  Map<String, int> _monthlyTotals = {}; // 매장별 월 누계 저장용

  String _periodMode = '월별'; // '월별', '년별', '전체'
  DateTime _targetDate = DateTime.now(); // 선택된 기준 날짜

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 🚀 탭이 바뀔 때마다 build()를 다시 실행하게 함
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
      _initDashboard();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose(); // 메모리 해제
    super.dispose();
  }

  Future<void> _initDashboard() async {
    await _loadData();
  }

  // 🚀 모든 매장의 보고 상태를 업데이트하는 함수
  void _loadAllStatuses() {
    Map<String, String> statuses = {};
    _reports.forEach((uid, report) {
      statuses[uid] = report?.status ?? "";
    });

    if (mounted) {
      setState(() {
        _storeStatuses = statuses;
      });
    }
  }
  Future<void> _handleBiometricLogin() async {
    final helper = BiometricHelper(); // 아까 만든 헬퍼 호출

    // 1. 기기가 생체 인식을 지원하는지 확인
    bool available = await helper.isAvailable();
    if (!available) {
      _showSnackBar("이 기기는 생체 인식을 지원하지 않거나 설정되지 않았습니다.");
      return;
    }

    // 2. 생체 인증 실행 (팝업 뜸)
    bool authenticated = await helper.authenticate();

    if (authenticated) {
      // 3. 인증 성공 시 저장된 정보 확인
      final info = await helper.getSavedLoginInfo();

      if (info['email'] != null && info['password'] != null) {
        setState(() => _isLoading = true);
        try {
          // 🚀 실제 로그인 시도
          await Provider.of<AuthProvider>(context, listen: false)
              .login(info['email']!, info['password']!);
        } catch (e) {
          _showSnackBar("자동 로그인 중 오류가 발생했습니다.");
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        _showSnackBar("저장된 정보가 없습니다. 먼저 일반 로그인을 1회 완료해주세요.");
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // 🚀 데이터 로드 함수 (일일 보고서 + 월 누계 병렬 로드)
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. 매장 목록 가져오기
      final stores = await ReportService().getAllStores();

      // 🚀 2. 일일 보고서와 월 누계 데이터를 병렬(Future.wait)로 로드하여 속도를 높입니다.
      final results = await Future.wait([
        Future.wait(stores.map((s) => ReportService().getReport(_selectedDate, s['id'].toString()))),
        ReportService().getMonthlyStoreTotals(_selectedDate),
      ]);

      final List<DailyReport?> reportsList = results[0] as List<DailyReport?>;
      final Map<String, int> monthlyTotals = results[1] as Map<String, int>;

      // 3. 맵 형태로 변환
      Map<String, DailyReport?> fetchedReports = {};
      for (int i = 0; i < stores.length; i++) {
        fetchedReports[stores[i]['id'].toString()] = reportsList[i];
      }

      if (mounted) {
        setState(() {
          _stores = stores;
          _reports = fetchedReports;
          _monthlyTotals = monthlyTotals; // 🚀 실제 월 누계 데이터 반영
        });
        _loadAllStatuses();
      }
    } catch (e) {
      print("❌ 데이터 로드 실패: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 날짜 제어 및 상세보기 로직 (기존과 동일하게 유지) ---
  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadData();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2004),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: khakiMain)),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  void _showFullDetail(DailyReport? report) {
    if (report == null) return;

    // 수정 여부 판단 (1분 이상 차이 시)
    bool isEdited = false;
    if (report.createdAt != null && report.updatedAt != null) {
      isEdited = report.updatedAt!.difference(report.createdAt!).inSeconds > 5;
    }

    // 시간 및 날짜 포맷팅 (한국형)
    String reportTime = report.updatedAt != null
        ? DateFormat('HH:mm').format(report.updatedAt!)
        : "정보 없음";

    // DB의 yyyy-MM-dd 형식을 yyyy년 M월 d일 형식으로 변환
    String formattedDate = report.date;
    try {
      DateTime parsedDate = DateTime.parse(report.date);
      formattedDate = "${parsedDate.year}년${parsedDate.month}월${parsedDate.day}일";
    } catch (e) {
      formattedDate = report.date;
    }

    Map<String, dynamic>? storeInfo;
    for (var s in _stores) {
      if (s['id'].toString() == report.storeId) {
        storeInfo = s;
        break;
      }
    }
    storeInfo ??= {'name': report.storeId, 'id': report.storeId, 'storeId': report.storeId};
    final String displayName = storeInfo['name'] ?? storeInfo['storeId'] ?? report.storeId;

    final String finalTitle = "$formattedDate $displayName 마감내역";

    showDialog(
      context: context,
      builder: (context) => ReportDetailDialog(
        report: report,
        title: finalTitle,
        content: SingleChildScrollView(
          child: Column(
            children: [
              // 🚀 상단 알림 영역 (구조 최적화 및 중복 제거 완료)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  border: Border.all(color: khakiMain.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 🚀 왼쪽: 정보 영역 (Expanded를 사용하여 버튼을 제외한 남은 공간을 확보)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person, size: 18, color: khakiMain),
                              const SizedBox(width: 8),
                              // 🚀 Flexible로 감싸서 이름이 길어도 뱃지를 밀어내지 않게 조절
                              Flexible(
                                child: Text(
                                  "책임자: ${report.author}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (isEdited) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                                  child: const Text("수정됨", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ]
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text("최종 보고: $reportTime", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),

                    // 정보 영역과 버튼 사이의 간격
                    const SizedBox(width: 10),

                    // 🚀 오른쪽: [본부장 권한] 수정 잠금 해제 버튼
                    if (report.status == 'complete')
                      SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: () => _unlockReport(report),
                          icon: const Icon(Icons.lock_open, size: 12),
                          label: const Text("수정 허용"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              elevation: 0,
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              _buildSectionHeader("오전 보고 현황", Icons.wb_sunny_outlined),
              _buildDetailTable("근무인원", report.staffCounts, unit: "명"),
              _buildDetailTable("오전재고", report.morningPrep, unit: "개"),
              _buildDetailList("유통기한 목록", report.expiryLog),
              _buildDetailSection("예약사항", report.reservation),
              _buildDetailSection("오전 특이사항", report.morningNote),

              _buildSectionHeader("매출 및 판매 현황", Icons.bar_chart),
              _buildDetailTable("시간대별 매출", report.salesTime),
              _buildDetailTable("주간판매량", report.dayVolume ?? {}, unit: "개"),
              _buildDetailTable("야간판매량", report.nightVolume ?? {}, unit: "개"),

              _buildSectionHeader("마감 및 정산", Icons.nights_stay_outlined),
              _buildDetailTable("마감내역", {
                "총 매출액": report.grandTotal,
                ...report.cashFlow,
                "카드매출": report.cardSales
              }),
              _buildDetailList("지출내역", report.expenseList),
              _buildDetailSection("입사", report.hiring),
              _buildDetailSection("퇴사", report.leaving),
              _buildDetailSection("마감 특이사항", report.closingNote),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI 헬퍼 메서드들 (생략 없이 모두 유지) ---
  Widget _buildDetailTable(String title, Map<String, dynamic> data, {String unit = '원'}) {
    final currencyFormat = NumberFormat('#,###');
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: khakiMain, fontSize: 16)),
          const Divider(color: khakiMain, thickness: 1),
          const SizedBox(height: 8),
          Table(
            border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
            columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1.5)},
            children: data.entries.map((entry) {
              if (entry.value is Map) {
                final Map innerMap = entry.value;
                final String formattedContent = innerMap.entries.map((innerEntry) {
                  final value = innerEntry.value;
                  final formattedValue = (value is num) ? "${currencyFormat.format(value)}$unit" : value.toString();
                  return "${innerEntry.key}: $formattedValue";
                }).join('\n');
                return TableRow(children: [
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))),
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(formattedContent, style: const TextStyle(height: 1.4, fontSize: 13))),
                ]);
              }
              return TableRow(children: [
                Padding(padding: const EdgeInsets.all(8.0), child: Text(entry.key, style: const TextStyle(color: Colors.black54))),
                Padding(padding: const EdgeInsets.all(8.0), child: Text(entry.value is num ? currencyFormat.format(entry.value) : entry.value.toString(), style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              ]);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: Colors.white,
      child: Column(
        children: [
          // 1. 모드 선택 (월별 / 년별 / 전체)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ['월별', '년별', '전체'].map((mode) {
              bool isSelected = _periodMode == mode;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(mode),
                  selected: isSelected,
                  selectedColor: khakiMain,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                  onSelected: (val) => setState(() => _periodMode = mode),
                ),
              );
            }).toList(),
          ),

          // 2. 세부 날짜 선택 (전체가 아닐 때만 노출)
          if (_periodMode != '전체')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: () => _pickPeriodDate(),
                icon: const Icon(Icons.calendar_view_month, size: 18, color: khakiMain),
                label: Text(
                  _periodMode == '월별'
                      ? DateFormat('yyyy년 MM월').format(_targetDate)
                      : DateFormat('yyyy년').format(_targetDate),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: khakiMain),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: khakiMain),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
        ],
      ),
    );
  }

// 월/년 선택을 위한 팝업 (간단하게 구현)
  // 🚀 수정된 연/월 전용 선택 함수
  Future<void> _pickPeriodDate() async {
    // 🚀 현재 연도와 시작 연도(2004) 사이의 차이를 계산합니다.
    int currentYear = DateTime.now().year;
    int startYear = 2004;
    int yearCount = currentYear - startYear + 1; // 2004년부터 현재까지의 총 연도 개수

    if (_periodMode == '월별') {
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 🚀 왼쪽 화살표: 2004년까지만 내려가도록 제한
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _targetDate.year > startYear
                        ? () => setDialogState(() => _targetDate = DateTime(_targetDate.year - 1, _targetDate.month))
                        : null, // 2004년 이하로는 클릭 안됨
                  ),
                  Text("${_targetDate.year}년", style: const TextStyle(fontWeight: FontWeight.bold)),
                  // 🚀 오른쪽 화살표: 현재 연도까지만 올라가도록 제한
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _targetDate.year < currentYear
                        ? () => setDialogState(() => _targetDate = DateTime(_targetDate.year + 1, _targetDate.month))
                        : null,
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    int month = index + 1;
                    bool isSelected = _targetDate.month == month;
                    return InkWell(
                      onTap: () {
                        setState(() => _targetDate = DateTime(_targetDate.year, month));
                        Navigator.pop(context);
                      },
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSelected ? khakiMain : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text("$month월", style: TextStyle(color: isSelected ? Colors.white : Colors.black)),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      );
    } else if (_periodMode == '년별') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
              "연도 선택",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
          ),
          content: SizedBox(
            width: 200,  // 🚀 너비 축소
            height: 180, // 🚀 높이를 절반 수준으로 고정 (스크롤 발생 지점)
            child: GridView.builder(
              // shrinkWrap은 해제하여 부모의 height 안에서 스크롤되게 합니다.
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // 3열로 배치
                childAspectRatio: 2.0,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: yearCount,
              itemBuilder: (context, index) {
                int year = currentYear - index;
                bool isSelected = _targetDate.year == year;
                return InkWell(
                  onTap: () {
                    setState(() => _targetDate = DateTime(year, 1));
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? khakiMain : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? khakiMain : Colors.grey.shade300),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "$year",
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("닫기", style: TextStyle(color: Colors.grey))
            )
          ],
        ),
      );
    }
  }

  Widget _buildDetailList(String title, List<Map<String, dynamic>> listData) {
    if (listData.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: khakiMain, fontSize: 16)),
          const Divider(color: khakiMain, thickness: 1),
          const SizedBox(height: 8),
          ...listData.map((item) {
            String displayText;

            // 🚀 유통기한 목록일 경우 전용 포맷 적용 (돼지갈비 | 1.0개 | 2월 27일)
            if (title == "유통기한 목록" && item.containsKey('item')) {
              String dateStr = item['date']?.toString() ?? "";
              String formattedDate = dateStr;

              // 1. 날짜 가공 (2026-02-27 -> 2월 27일)
              if (dateStr.length >= 10) {
                DateTime? dt = DateTime.tryParse(dateStr);
                if (dt != null) {
                  formattedDate = "${dt.month}월 ${dt.day}일";
                }
              }

              // 2. 원하는 순서로 배치
              displayText = "${item['item']} | ${item['note']} | $formattedDate";
            } else {
              // 그 외 지출내역 등은 기존 방식 유지
              displayText = item.entries.map((e) => "${e.key}: ${e.value}").join("  |  ");
            }

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300, width: 0.5)
              ),
              child: Text(
                  displayText,
                  style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500)
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Icon(icon, color: khakiMain, size: 22),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: khakiMain)),
          const SizedBox(width: 10),
          const Expanded(child: Divider(thickness: 2, color: khakiMain)),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, String? content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: khakiMain, fontSize: 16)),
          const Divider(color: khakiMain, thickness: 1),
          const SizedBox(height: 8),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
            child: Text(content ?? '기록된 내용이 없습니다.', style: const TextStyle(height: 1.5)),
          ),
        ],
      ),
    );
  }

  void _showStoreSelectDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("매장 항목 설정"),
        content: SizedBox(
          width: double.maxFinite,
          child: _stores.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              : ListView.builder(
            shrinkWrap: true,
            itemCount: _stores.length,
            itemBuilder: (context, index) {
              final store = _stores[index];
              final String rawName = store['name'] ?? '이름 없음';
              final String displayName = kStoreNames[rawName] ?? rawName;
              return ListTile(
                leading: const Icon(Icons.store, color: khakiMain),
                title: Text(displayName),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => StoreConfigScreen(storeUid: store['id'], storeName: displayName)));
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("닫기"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: khakiMain,
        title: const Text("본부장 대시보드"),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController, // 👈 컨트롤러 연결
          indicatorColor: Colors.white,
          tabs: const [Tab(text: "전체 매장"), Tab(text: "매장별 기록")],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'settings') {
                _showStoreSelectDialog();
              } else if (value == 'refresh') {
                _loadData();
              } else if (value == 'logout') {
                await Provider.of<AuthProvider>(context, listen: false).logout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings), SizedBox(width: 10), Text("매장 항목 설정")])),
              const PopupMenuItem(value: 'refresh', child: Row(children: [Icon(Icons.refresh), SizedBox(width: 10), Text("데이터 새로고침")])),
              const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, color: Colors.redAccent), SizedBox(width: 10), Text("로그아웃")])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 🚀 [핵심 수정] 0번 탭(전체 매장)일 때만 날짜 선택기를 보여줍니다.
          if (_tabController.index == 0) _buildDateSelector(),
          if (_tabController.index == 1) _buildPeriodSelector(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: khakiMain))
                : TabBarView(
              controller: _tabController, // 컨트롤러 연결
              children: [
                AdminSalesTab(
                    stores: _stores,
                    reports: _reports,
                    storeStatuses: _storeStatuses,
                    monthlyTotals: _monthlyTotals,
                    onStoreTap: _showFullDetail
                ),
                AdminRecordsTab(
                  stores: _stores,
                  onStoreTap: _showFullDetail,
                  periodMode: _periodMode ?? '월별',     // 전달
                  targetDate: _targetDate ?? DateTime.now(), // 기간 정보 전달
                )
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2, offset: const Offset(0, 1))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left, color: khakiMain), onPressed: () => _changeDate(-1)),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: khakiMain.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, size: 18, color: khakiMain),
                  const SizedBox(width: 8),
                  Text(DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, color: khakiMain, fontSize: 16)),
                ],
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.chevron_right, color: khakiMain), onPressed: () => _changeDate(1)),
        ],
      ),
    );
  }

  Future<void> _unlockReport(DailyReport report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("수정 권한 부여"),
        content: const Text("매니저가 내용을 수정할 수 있도록 잠금을 해제하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("취소")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("해제하기")),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 🚀 DB의 status를 'writing'으로 변경하여 매니저에게 편집권을 돌려줌
        await ReportService().updateReportStatus(report.date, report.storeId, 'writing');
        if (mounted) {
          Navigator.pop(context); // 상세창 닫기
          _loadData(); // 대시보드 새로고침
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 해당 보고서의 수정 잠금이 해제되었습니다.")));
        }
      } catch (e) {
        debugPrint("잠금 해제 실패: $e");
      }
    }
  }
}
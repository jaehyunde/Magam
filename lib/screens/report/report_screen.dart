// lib/screens/report/report_screen.dart 수정본
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'tab_day.dart';
import 'tab_sales.dart';
import 'tab_closing.dart';
import '../records/records_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../common/constants.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as custom;

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int _selectedIndex = 0;
  final GlobalKey<RecordsScreenState> _recordsKey = GlobalKey<RecordsScreenState>();
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'ko_KR';
    _initBusinessDate();
  }

  // 초기 날짜 세팅 로직 유지
  void _initBusinessDate() {
    final now = DateTime.now();
    if (now.hour < 10) {
      _selectedDate = now.subtract(const Duration(days: 1));
    } else {
      _selectedDate = now;
    }
  }

  // 🚀 [추가] 날짜를 좌우로 넘기는 기능 (본부장 페이지와 동일)
  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  // 달력 팝업 함수 (디자인 통일)
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: khakiMain),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(child: const Text('취소'), onPressed: () => Navigator.of(context).pop()),
          TextButton(child: const Text('로그아웃'), onPressed: () {
            Navigator.of(context).pop();
            _logout();
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 1. 'custom.AuthProvider'를 가져옵니다.
    final authProvider = Provider.of<custom.AuthProvider>(context);

    // 🚀 2. 'userProfile' 대신 'user'를 사용합니다 (UserModel 타입).
    final userModel = authProvider.user;

    // 🚀 3. UserModel 안에 정의된 storeId를 가져와서 한국어로 변환합니다.
    final String englishStoreId = userModel?.storeId ?? "";
    final String storeDisplayName = kStoreNames[englishStoreId] ?? "매장";

    final List<Widget> pages = [
      DayTab(selectedDate: _selectedDate),
      SalesTab(selectedDate: _selectedDate),
      ClosingTab(selectedDate: _selectedDate),
      RecordsScreen(key: _recordsKey, selectedDate: _selectedDate),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: khakiMain,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        // 🚀 3. 동적으로 결정된 매장명을 타이틀에 적용합니다.
        title: Text(
            "$storeDisplayName 업무 보고",
            style: const TextStyle(fontWeight: FontWeight.bold)
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _recordsKey.currentState?.fetchReport(_selectedDate),
            tooltip: '데이터 새로고침',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutConfirmationDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          Expanded(
            child: SafeArea(
              child: IndexedStack(
                index: _selectedIndex,
                children: pages,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: khakiMain,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined), label: '근무현황'),
            BottomNavigationBarItem(icon: Icon(Icons.point_of_sale_outlined), label: '매출/운영'),
            BottomNavigationBarItem(icon: Icon(Icons.calculate_outlined), label: '마감/정산'),
            BottomNavigationBarItem(icon: Icon(Icons.history_edu_outlined), label: '기록열람'),
          ],
        ),
      ),
    );
  }

  // 📅 [추가] 날짜 선택 바 위젯 (디자인 통일)
  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 2, offset: const Offset(0, 1))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: khakiMain),
            onPressed: () => _changeDate(-1),
          ),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: khakiMain.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, size: 18, color: khakiMain),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(_selectedDate),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: khakiMain, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: khakiMain),
            onPressed: () => _changeDate(1),
          ),
        ],
      ),
    );
  }
}
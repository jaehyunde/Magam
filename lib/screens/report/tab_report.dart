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

// 🚀 1. 기간 구분을 위한 Enum (파일 최상단에 위치)
enum ReportPeriod { day, month, year, total }

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int _selectedIndex = 0;
  final GlobalKey<RecordsScreenState> _recordsKey = GlobalKey<RecordsScreenState>();
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  // 🚀 2. 현재 선택된 기간 상태
  ReportPeriod _selectedPeriod = ReportPeriod.day;

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'ko_KR';
    _initBusinessDate();
  }

  void _initBusinessDate() {
    final now = DateTime.now();
    if (now.hour < 10) {
      _selectedDate = now.subtract(const Duration(days: 1));
    } else {
      _selectedDate = now;
    }
  }

  // 🚀 3. 기간에 따라 날짜/월/년을 넘기는 로직 개선
  void _changeDate(int value) {
    setState(() {
      if (_selectedPeriod == ReportPeriod.month) {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + value, _selectedDate.day);
      } else if (_selectedPeriod == ReportPeriod.year) {
        _selectedDate = DateTime(_selectedDate.year + value, _selectedDate.month, _selectedDate.day);
      } else {
        _selectedDate = _selectedDate.add(Duration(days: value));
      }
    });
  }

  Future<void> _logout() async {
    final authProvider = Provider.of<custom.AuthProvider>(context, listen: false);
    await authProvider.logout();
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
    final authProvider = Provider.of<custom.AuthProvider>(context);
    final userModel = authProvider.user;
    final String englishStoreId = userModel?.storeId ?? "";
    final String storeDisplayName = kStoreNames[englishStoreId] ?? "매장";

    final List<Widget> pages = [
      DayTab(selectedDate: _selectedDate),
      SalesTab(selectedDate: _selectedDate),
      ClosingTab(selectedDate: _selectedDate),
      RecordsScreen(
          key: _recordsKey,
          selectedDate: _selectedDate,
          period: _selectedPeriod
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: khakiMain,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        title: Text("$storeDisplayName 업무 보고", style: const TextStyle(fontWeight: FontWeight.bold)),
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
          if (_selectedIndex == 3) _buildPeriodToggle(),
          if (_selectedPeriod != ReportPeriod.total) _buildDateSelector(),
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
        decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
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

  Widget _buildPeriodToggle() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: SegmentedButton<ReportPeriod>(
        segments: const [
          ButtonSegment(value: ReportPeriod.day, label: Text('하루'), icon: Icon(Icons.today)),
          ButtonSegment(value: ReportPeriod.month, label: Text('한달'), icon: Icon(Icons.calendar_view_month)),
          ButtonSegment(value: ReportPeriod.year, label: Text('일년'), icon: Icon(Icons.calendar_today)),
          ButtonSegment(value: ReportPeriod.total, label: Text('전체'), icon: Icon(Icons.all_inclusive)),
        ],
        selected: {_selectedPeriod},
        onSelectionChanged: (Set<ReportPeriod> newSelection) {
          setState(() => _selectedPeriod = newSelection.first);
          _recordsKey.currentState?.fetchReport(_selectedDate);
        },
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: khakiMain,
          selectedForegroundColor: Colors.white,
          side: const BorderSide(color: khakiMain),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    String dateText;
    switch (_selectedPeriod) {
      case ReportPeriod.month:
        dateText = DateFormat('yyyy년 MM월').format(_selectedDate);
        break;
      case ReportPeriod.year:
        dateText = DateFormat('yyyy년').format(_selectedDate);
        break;
      default:
        dateText = DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(_selectedDate);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
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
              decoration: BoxDecoration(color: khakiMain.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, size: 18, color: khakiMain),
                  const SizedBox(width: 8),
                  Text(dateText, style: const TextStyle(fontWeight: FontWeight.bold, color: khakiMain, fontSize: 16)),
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

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();

    // 1. [하루] 모드: 일반 달력
    if (_selectedPeriod == ReportPeriod.day) {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
        firstDate: DateTime(2004),
        lastDate: DateTime.now(),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: khakiMain)),
          child: child!,
        ),
      );
      if (picked != null) setState(() => _selectedDate = picked);
    }

    // 2. [한달] 모드: 연도와 월만 선택하는 다이얼로그
    else if (_selectedPeriod == ReportPeriod.month) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("월 선택"),
            content: SizedBox(
              width: 300,
              height: 350,
              child: MonthPicker( // 아래에 정의할 커스텀 위젯
                initialDate: _selectedDate,
                onDateSelected: (DateTime selected) {
                  setState(() => _selectedDate = selected);
                  Navigator.pop(context);
                },
              ),
            ),
          );
        },
      );
    }

    // 3. [일년] 모드: 연도만 선택하는 다이얼로그
    else if (_selectedPeriod == ReportPeriod.year) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("연도 선택"),
            content: SizedBox(
              width: 300,
              height: 250,
              child: CustomYearPicker( // 🚀 우리가 만든 내림차순 선택기
                selectedDate: _selectedDate,
                onYearSelected: (DateTime dateTime) {
                  setState(() => _selectedDate = dateTime);
                  Navigator.pop(context);
                },
              ),
            ),
          );
        },
      );
    }
  }
}

class MonthPicker extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateSelected;

  const MonthPicker({super.key, required this.initialDate, required this.onDateSelected});

  @override
  State<MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<MonthPicker> {
  late int _displayYear;

  @override
  void initState() {
    super.initState();
    _displayYear = widget.initialDate.year; // 현재 보고 있는 연도 초기화
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 🚀 연도 선택 헤더 (좌우 화살표 추가)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: khakiMain),
              onPressed: () => setState(() => _displayYear--), // 연도 감소
            ),
            Text(
              "$_displayYear년",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: khakiMain),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: khakiMain),
              // 미래 데이터는 현재 연도까지만 볼 수 있도록 제한 (선택 사항)
              onPressed: _displayYear < DateTime.now().year
                  ? () => setState(() => _displayYear++)
                  : null,
            ),
          ],
        ),
        const Divider(),
        Expanded(
          child: GridView.builder(
            itemCount: 12,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.5,
            ),
            itemBuilder: (context, index) {
              final month = index + 1;
              // 선택된 연도와 월이 모두 일치할 때만 하이라이트
              final isSelected = widget.initialDate.year == _displayYear && widget.initialDate.month == month;

              return InkWell(
                onTap: () => widget.onDateSelected(DateTime(_displayYear, month)),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected ? khakiMain : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Center(
                    child: Text(
                      "$month월",
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class CustomYearPicker extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onYearSelected;

  const CustomYearPicker({super.key, required this.selectedDate, required this.onYearSelected});

  @override
  Widget build(BuildContext context) {
    final int currentYear = DateTime.now().year;
    final int startYear = 2004;
    final List<int> years = List.generate(
        currentYear - startYear + 1,
            (index) => startYear + index
    ).reversed.toList();

    return GridView.builder(
      itemCount: years.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 한 줄에 3개씩
        childAspectRatio: 1.8,
      ),
      itemBuilder: (context, index) {
        final year = years[index];
        final isSelected = selectedDate.year == year;

        return InkWell(
          onTap: () => onYearSelected(DateTime(year, selectedDate.month)),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected ? khakiMain : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Text(
                "$year년",
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
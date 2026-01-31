import 'package:flutter/material.dart';
import '../../services/report_service.dart';
import '../../common/constants.dart';

class StoreConfigScreen extends StatefulWidget {
  final String storeUid;
  final String storeName;

  const StoreConfigScreen({super.key, required this.storeUid, required this.storeName});

  @override
  State<StoreConfigScreen> createState() => _StoreConfigScreenState();
}

class _StoreConfigScreenState extends State<StoreConfigScreen> {
  List<String> salesItems = [];
  List<String> expenseItems = [];
  List<String> menuItems = [];
  List<String> salesTimeItems = [];
  List<String> salesCategoryItems = [];
  List<String> dayStaffItems = [];
  List<Map<String, dynamic>> morningMenuItems = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  // lib/screens/admin/store_config_screen.dart 내 _loadConfig 함수

  void _loadConfig() async {
    // 🚀 타입을 명시적으로 Map<String, dynamic>? 로 선언
    Map<String, dynamic>? config = await ReportService().getStoreConfig(widget.storeUid);
    config ??= kDefaultStoreConfig;

    if (mounted) {
      setState(() {
        salesItems = List<String>.from(config!['sales'] ?? []);
        expenseItems = List<String>.from(config['expenses'] ?? []);
        menuItems = List<String>.from(config['menu'] ?? []);
        salesTimeItems = List<String>.from(config['salesTime'] ?? []);
        salesCategoryItems = List<String>.from(config['salesCategory'] ?? []);

        dayStaffItems = List<String>.from(config['dayStaff'] ?? kDefaultStoreConfig['dayStaff'] ?? []);
        // morningMenu 로드 (기존에 드린 코드 유지)
        morningMenuItems = (config['morningMenu'] as List?)?.map((item) => Map<String, dynamic>.from(item)).toList()
            ?? [];
        isLoading = false;
      });
    }
  }

  void _addItem(String title, List<String> targetList) {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$title 추가"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "항목 이름을 입력하세요"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => targetList.add(controller.text.trim()));
                Navigator.pop(context);
              }
            },
            child: const Text("추가"),
          )
        ],
      ),
    );
  }

  void _addMorningMenu() {
    TextEditingController controller = TextEditingController();
    bool hasExpiry = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text("오전 준비 메뉴 추가"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: "메뉴 이름을 입력하세요"),
                autofocus: true,
              ),
              CheckboxListTile(
                title: const Text("유통기한 관리 여부"),
                value: hasExpiry,
                onChanged: (val) => setDlgState(() => hasExpiry = val!),
                activeColor: khakiMain,
                contentPadding: EdgeInsets.zero,
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소")),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    morningMenuItems.add({
                      'name': controller.text.trim(),
                      'hasExpiry': hasExpiry,
                    });
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text("추가"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.storeName} 항목 설정"),
        backgroundColor: khakiMain,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              // 🚀 [타입 에러 해결] Map<String, dynamic>으로 전달
              final Map<String, dynamic> configData = {
                'sales': salesItems,
                'expenses': expenseItems,
                'menu': menuItems,
                'salesTime': salesTimeItems,
                'salesCategory': salesCategoryItems,
                'dayStaff': dayStaffItems,
                'morningMenu': morningMenuItems,
              };

              await ReportService().saveStoreConfig(widget.storeUid, configData);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("설정이 저장되었습니다.")),
                );
                Navigator.pop(context);
              }
            },
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection("마감 항목 관리", salesItems),
          const SizedBox(height: 20),
          _buildSection("지출 목록 관리", expenseItems),
          const SizedBox(height: 20),
          _buildSection("매출 시간 관리", salesTimeItems),
          const SizedBox(height: 20),
          _buildSection("매출 분류 관리", salesCategoryItems),
          const SizedBox(height: 20),
          _buildSection("근무 인원 관리", dayStaffItems),
          const SizedBox(height: 20),
          _buildMorningMenuSection("오전 준비 메뉴 관리", morningMenuItems),
          const SizedBox(height: 20),
          _buildSection("재고 품목 관리", menuItems),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<String> items) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle, color: khakiMain),
              onPressed: () => _addItem(title, items),
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("등록된 항목이 없습니다.", style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8,
              children: items.map((item) => Chip(
                label: Text(item, style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.grey.shade100,
                onDeleted: () => setState(() => items.remove(item)),
                deleteIconColor: Colors.red.shade300,
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMorningMenuSection(String title, List<Map<String, dynamic>> items) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle, color: khakiMain),
              onPressed: _addMorningMenu,
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("등록된 항목이 없습니다.", style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8,
              children: items.map((item) => Chip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item['name'], style: const TextStyle(fontSize: 12)),
                    if (item['hasExpiry'] == true)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.calendar_month, size: 12, color: khakiMain),
                      ),
                  ],
                ),
                backgroundColor: Colors.grey.shade100,
                onDeleted: () => setState(() => items.remove(item)),
                deleteIconColor: Colors.red.shade300,
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
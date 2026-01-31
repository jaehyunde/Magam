// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/report/report_screen.dart';
import 'screens/admin/admin_screen.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'screens/admin/admin_web_shell.dart';
import 'screens/admin_dashboard.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// 🎨 색상 상수를 전역으로 유지합니다.
const Color khakiMain = Color(0xFF4F5D2F);
const Color khakiLight = Color(0xFF8D9965);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  // 🚀 이미 firebase_options.dart를 잘 만드셨으므로 이 한 줄이면 충분합니다.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: '매장 통합 관리',
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // 🚀 3. 지원하는 언어 목록에 한국어를 넣습니다.
        supportedLocales: const [
          Locale('ko', 'KR'),
        ],
        // 🚀 4. 기본 언어를 한국어로 설정합니다.
        locale: const Locale('ko', 'KR'),

        theme: ThemeData(
          primaryColor: khakiMain,
          colorScheme: ColorScheme.fromSeed(
            seedColor: khakiMain,
            primary: khakiMain,
            secondary: khakiLight,
          ),
          useMaterial3: false,
          fontFamily: 'Eulyoo1945',
        ),

        // lib/main.dart 수정본

        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            // 1. 로그인 상태 확인 (자동 로그인 포함)
            if (!auth.isAuthenticated) {
              return const LoginScreen();
            }

            if (auth.isAdmin) {
              // 웹이면 웹용 대시보드, 모바일이면 앱용 대시보드로 보냄
              return kIsWeb ? const AdminWebDashboard() : const AdminDashboard();
            }
            return const ReportScreen();
          },
        ),

        // 이동할 페이지들을 정의해둡니다 (Navigator.push 사용 시 필요)
        routes: {
          '/login': (context) => const LoginScreen(),
          '/report': (context) => const ReportScreen(),
          '/admin': (context) => const AdminDashboard(),
          '/web_admin': (context) => const AdminWebDashboard(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
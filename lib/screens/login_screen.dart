// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'report/tab_report.dart';
import 'admin_dashboard.dart';
import '../common/constants.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/biometric_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState(); // 👈 부모의 기능을 먼저 호출하는 것이 필수입니다.

    // 🚀 화면이 완전히 그려진 직후(PostFrame)에 실행되도록 예약합니다.
    // 이 작업을 안 하면 화면이 뜨기도 전에 팝업을 띄우려다 에러가 날 수 있습니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoBiometricLogin();
    });
  }

  Future<void> _autoBiometricLogin() async {
    final helper = BiometricHelper();
    final info = await helper.getSavedLoginInfo();

    // 저장된 이메일과 비번이 모두 있을 때만 지문 팝업을 띄웁니다.
    if (info['email'] != null && info['password'] != null) {
      _handleBiometricLogin(); // 본부장님이 이미 만들어두신 함수 호출!
    }
  }

  // 생체 인증 로그인
  Future<void> _handleBiometricLogin() async {
    final helper = BiometricHelper();

    // 지원 여부 확인
    bool available = await helper.isAvailable();
    if (!available) {
      _showSnackBar("생체 인식을 사용할 수 없는 기기입니다.", isError: true);
      return;
    }

    bool authenticated = await helper.authenticate();

    if (authenticated) {
      setState(() => _isLoading = true);

      final info = await helper.getSavedLoginInfo();

      if (info['email'] != null && info['password'] != null) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        String? error = await authProvider.login(info['email']!, info['password']!);

        if (error != null && mounted) {
          _showSnackBar(error, isError: true);
        }
      } else {
        _showSnackBar("저장된 정보가 없습니다. 수동 로그인을 먼저 해주세요.");
      }

      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 수동 로그인 로직
  void _tryLogin() async {
    final email = _emailController.text.trim(); // 🚀 변수 선언 추가
    final password = _passwordController.text.trim(); // 🚀 변수 선언 추가

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar("아이디와 비밀번호를 입력해주세요.", isError: true);
      return;
    }

    setState(() { _isLoading = true; });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String? error = await authProvider.login(email, password);

    if (!mounted) return;
    setState(() { _isLoading = false; });

    if (error != null) {
      _showSnackBar(error, isError: true);
    } else {
      // 🚀 로그인 성공 시 정보 저장
      await BiometricHelper().saveLoginInfo(email, password);
      print("🚩 로그인 정보 저장 완료");
    }
  }

  // 3️⃣ 공통 스낵바 알림 함수
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.black87,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.store, size: 80, color: khakiMain),
              const SizedBox(height: 20),
              const Text(
                '매장 통합 관리 시스템',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              // 🚀 헬퍼 위젯을 사용하여 깔끔하게 정리
              _buildTextField(_emailController, '아이디', Icons.email, TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildTextField(_passwordController, '비밀번호', Icons.lock, TextInputType.text, isObscure: true),
              const SizedBox(height: 30),

              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _tryLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: khakiMain,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('로그인', style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 55,
                    width: 55,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: khakiMain, width: 1.5),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Theme.of(context).platform == TargetPlatform.iOS
                            ? Icons.face_retouching_natural
                            : Icons.fingerprint,
                        color: khakiMain,
                        size: 30,
                      ),
                      onPressed: _isLoading ? null : _handleBiometricLogin,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 텍스트 필드 빌더 헬퍼
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, TextInputType type, {bool isObscure = false}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
} // 🚀 마지막에 중복되었던 중괄호 제거 완료
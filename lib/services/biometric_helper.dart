// lib/services/biometric_helper.dart
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricHelper {
  final LocalAuthentication _auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();

  // 1. 이 기기가 생체 인식을 지원하는지 확인
  Future<bool> isAvailable() async {
    final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
    final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
    return canAuthenticate;
  }

  // 2. 실제 지문/Face ID 인증 실행
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: '안전한 로그인을 위해 본인 인증을 진행해주세요.',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      print("❌ 인증 에러: $e");
      return false;
    }
  }

  // 3. 로그인 정보 저장 (로그인 성공 시 호출)
  Future<void> saveLoginInfo(String email, String password) async {
    await _storage.write(key: 'saved_email', value: email);
    await _storage.write(key: 'saved_password', value: password);
    await _storage.write(key: 'use_biometric', value: 'true');
  }

  // 4. 저장된 정보 가져오기
  Future<Map<String, String?>> getSavedLoginInfo() async {
    String? email = await _storage.read(key: 'saved_email');
    String? password = await _storage.read(key: 'saved_password');
    return {'email': email, 'password': password};
  }
}
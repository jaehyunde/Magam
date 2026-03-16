// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _user;
  UserModel? get user => _user;

  bool get isAdmin => _user?.role == 'admin';
  bool get isManager => _user?.role == 'manager';
  // 앱에 들어올 수 있는 사람인가? (본부장 또는 매니저)
  bool get isAuthorized => isAdmin || isManager;

  bool get isAuthenticated => _user != null;

  AuthProvider() {
    // 🚀 [1번 문제 해결] 자동 로그인 차단
    // 기존에 세션이 남아있더라도, 앱 시작 시 무시하도록 주석 처리하거나 로그아웃을 명시합니다.
    // _checkCurrentUser(); // 이 부분을 주석 처리하여 자동 로그인을 방지합니다.
    _forceLogoutOnStart();
  }

  // 앱 실행 시 기존 세션을 완전히 비우는 함수
  void _forceLogoutOnStart() async {
    await _auth.signOut();
    _user = null;
    debugPrint("✅ 시스템 시작: 기존 세션을 초기화하고 로그인 화면으로 진입합니다.");
  }

  Future<String?> login(String email, String password) async {
    try {
      debugPrint("🚀 로그인 프로세스 시작: $email");
      _user = null;
      notifyListeners();

      // 1. Firebase 인증
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint("1️⃣ Firebase 인증 성공: ${userCredential.user!.uid}");

      // 2. DB 정보 가져오기
      String uid = userCredential.user!.uid;
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        debugPrint("2️⃣ Firestore 문서 발견: ${doc.data()}");

        // 🚀 [2번 문제 진단] 데이터 매핑 중 에러가 나는지 확인
        try {
          _user = UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
          debugPrint("3️⃣ 유저 모델 매핑 성공: Role = ${_user?.role}");
        } catch (e) {
          debugPrint("❌ 유저 모델 매핑 실패 (데이터 타입 불일치 등): $e");
          return "데이터 매핑 오류: $e";
        }

        // 🚀 [2번 문제 진단] 권한 확인
        if (isAuthorized) {
          debugPrint("4️⃣ 권한 확인 완료: ${_user?.role} 입장 허가");
          notifyListeners();
          return null;
        } else {
          debugPrint("❌ 권한 거부: 등록되지 않은 역할(${_user?.role})");
          await _auth.signOut();
          _user = null;
          return '접근 권한이 없는 계정입니다.';
        }
      } else {
        await _auth.signOut();
        return '사용자 정보가 없습니다.';
      }
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      _user = null;
      notifyListeners();
      debugPrint("✅ 로그아웃 완료");
    } catch (e) {
      debugPrint("❌ 로그아웃 에러: $e");
    }
  }
}
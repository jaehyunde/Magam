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

  // manager 권한도 포함하여 체크
  bool get isAdmin => _user?.role == 'admin' || _user?.role == 'manager';
  bool get isAuthenticated => _user != null;

  // 생성자에서 강제 로그아웃 로직을 제거했습니다.
  // 대신 앱 시작 시 '현재 유저가 누구인지'만 확인합니다.
  AuthProvider() {
    _checkCurrentUser();
  }

  void _checkCurrentUser() {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _loadUserData(currentUser.uid);
    }
  }

  // 유저 데이터를 가져오는 공통 함수
  Future<void> _loadUserData(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      _user = UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
      notifyListeners();
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      // 🚀 [해결3] 로그인 시도 직전에 무조건 이전 상태를 초기화합니다.
      _user = null;
      notifyListeners();

      // 1. Firebase 인증
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. DB 정보 가져오기
      String uid = userCredential.user!.uid;
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        _user = UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);

        // 로그인 성공 후 반드시 알림을 주어 화면을 전환시킵니다.
        notifyListeners();
        return null;
      } else {
        await _auth.signOut(); // 정보 없으면 로그아웃
        return '사용자 정보가 시스템에 등록되지 않았습니다.';
      }
    } on FirebaseAuthException catch (e) {
      _user = null;
      notifyListeners();
      return e.message; // "비밀번호 틀림" 등의 메시지 반환
    } catch (e) {
      _user = null;
      notifyListeners();
      print('🔥🔥 로그인 에러: $e');
      return '로그인 프로세스 중 오류가 발생했습니다.';
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      _user = null; // 메모리 비우기
      notifyListeners(); // 로그인 페이지로 튕겨내기
      print("✅ 로그아웃 완료");
    } catch (e) {
      print("❌ 로그아웃 에러: $e");
    }
  }
}
// lib/models/user_model.dart

class UserModel {
  final String uid;       // Firebase 고유 ID
  final String email;     // 아이디(이메일)
  final String role;      // 역할: 'admin' 또는 'manager'
  final String? storeId;  // 담당 매장 ID (관리자는 null, 직원은 필수)

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    this.storeId,
  });

  // Firestore에서 가져온 데이터를 변환
  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      role: data['role'] ?? 'manager', // 기본값은 직원
      storeId: data['storeId'], // 관리자라면 null일 수 있음
    );
  }
}
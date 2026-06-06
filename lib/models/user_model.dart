class UserModel {
  final String uid;
  final String phone;
  final String role;
  final int loginAttempts;
  final bool isBlocked;

  UserModel({
    required this.uid,
    required this.phone,
    required this.role,
    this.loginAttempts = 0,
    this.isBlocked = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phone': phone,
      'role': role,
      'loginAttempts': loginAttempts,
      'isBlocked': isBlocked,
    };
  }
}
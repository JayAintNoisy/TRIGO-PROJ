class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final UserData user;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      user: UserData.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class UserData {
  final String id;
  final String email;
  final String name;
  final String? phone;
  final String role;
  final String? profilePhotoUrl;

  const UserData({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    required this.role,
    this.profilePhotoUrl,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
    );
  }
}

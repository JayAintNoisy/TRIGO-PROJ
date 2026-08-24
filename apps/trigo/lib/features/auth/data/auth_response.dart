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
  final String firstName;
  final String lastName;
  final String? phone;
  final String role;
  final String? profilePhotoUrl;
  final String? driverStatus;
  final bool driverIntent;

  const UserData({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    required this.role,
    this.profilePhotoUrl,
    this.driverStatus,
    this.driverIntent = false,
  });

  String get name => '$firstName $lastName'.trim();

  factory UserData.fromJson(Map<String, dynamic> json) {
    final driverProfile = json['driverProfile'];
    return UserData(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      driverStatus: driverProfile is Map
          ? driverProfile['applicationStatus'] as String?
          : null,
      driverIntent: json['driverIntent'] == true,
    );
  }
}

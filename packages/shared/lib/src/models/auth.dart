class LoginRequest {
  const LoginRequest({
    required this.tenantSlug,
    required this.username,
    required this.password,
  });

  final String tenantSlug;
  final String username;
  final String password;

  factory LoginRequest.fromJson(Map<String, dynamic> json) => LoginRequest(
        tenantSlug: json['tenant_slug'] as String,
        username: json['username'] as String,
        password: json['password'] as String,
      );

  Map<String, dynamic> toJson() => {
        'tenant_slug': tenantSlug,
        'username': username,
        'password': password,
      };
}

class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic> user;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        user: json['user'] as Map<String, dynamic>,
      );

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'user': user,
      };
}

class RefreshRequest {
  const RefreshRequest({required this.refreshToken});

  final String refreshToken;

  factory RefreshRequest.fromJson(Map<String, dynamic> json) => RefreshRequest(
        refreshToken: json['refresh_token'] as String,
      );

  Map<String, dynamic> toJson() => {'refresh_token': refreshToken};
}

class ChangePasswordRequest {
  const ChangePasswordRequest({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;

  factory ChangePasswordRequest.fromJson(Map<String, dynamic> json) =>
      ChangePasswordRequest(
        currentPassword: json['current_password'] as String,
        newPassword: json['new_password'] as String,
      );

  Map<String, dynamic> toJson() => {
        'current_password': currentPassword,
        'new_password': newPassword,
      };
}

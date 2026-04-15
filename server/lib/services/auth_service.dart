import 'package:bcrypt/bcrypt.dart';
import 'package:shared/shared.dart';

import '../jwt_service.dart';
import '../repositories/refresh_token_repository.dart';
import '../repositories/tenant_repository.dart';
import '../repositories/user_repository.dart';

class AuthService {
  AuthService({
    required this.tenantRepo,
    required this.userRepo,
    required this.refreshTokenRepo,
  });

  final TenantRepository tenantRepo;
  final UserRepository userRepo;
  final RefreshTokenRepository refreshTokenRepo;

  Future<Map<String, dynamic>> login({
    required String tenantSlug,
    required String username,
    required String password,
  }) async {
    final tenant = await tenantRepo.findBySlug(tenantSlug);
    if (tenant == null) throw Exception('Tenant not found');
    if (tenant['is_active'] != true) throw Exception('Tenant is inactive');

    final user = await userRepo.findByUsernameAndTenant(
      username,
      tenant['id'] as String,
    );
    if (user == null) throw Exception('Invalid credentials');
    if (user['is_active'] != true) throw Exception('User is inactive');

    final valid = BCrypt.checkpw(password, user['password_hash'] as String);
    if (!valid) throw Exception('Invalid credentials');

    final userId = user['id'] as String;
    final tenantId = tenant['id'] as String;
    final role = user['role'] as String;

    final accessToken = JwtService.instance.generateAccessToken(
      userId: userId,
      tenantId: tenantId,
      role: role,
    );
    final refreshToken = JwtService.instance.generateRefreshToken(
      userId: userId,
      tenantId: tenantId,
    );

    await refreshTokenRepo.store(
      userId: userId,
      token: refreshToken,
      expiresAt: DateTime.now().add(AppConstants.refreshTokenDuration),
    );

    // Remove password_hash from response
    user.remove('password_hash');

    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'user': user,
    };
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final payload = JwtService.instance.verifyToken(refreshToken);
    if (payload == null || payload['type'] != 'refresh') {
      throw Exception('Invalid refresh token');
    }

    final isValid = await refreshTokenRepo.validate(refreshToken);
    if (!isValid) throw Exception('Refresh token revoked or expired');

    // Revoke old token
    await refreshTokenRepo.revoke(refreshToken);

    final userId = payload['user_id'] as String;
    final user = await userRepo.findById(userId);
    if (user == null) throw Exception('User not found');

    final tenantId = user['tenant_id'] as String;
    final role = user['role'] as String;

    final newAccessToken = JwtService.instance.generateAccessToken(
      userId: userId,
      tenantId: tenantId,
      role: role,
    );
    final newRefreshToken = JwtService.instance.generateRefreshToken(
      userId: userId,
      tenantId: tenantId,
    );

    await refreshTokenRepo.store(
      userId: userId,
      token: newRefreshToken,
      expiresAt: DateTime.now().add(AppConstants.refreshTokenDuration),
    );

    return {
      'access_token': newAccessToken,
      'refresh_token': newRefreshToken,
      'user': user,
    };
  }

  Future<void> logout(String refreshToken) async {
    await refreshTokenRepo.revoke(refreshToken);
  }
}

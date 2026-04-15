import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shared/shared.dart';

class JwtService {
  JwtService._();
  static final JwtService instance = JwtService._();

  String get _secret =>
      Platform.environment['JWT_SECRET'] ?? 'dev-secret-change-in-production';

  String generateAccessToken({
    required String userId,
    required String tenantId,
    required String role,
  }) {
    final jwt = JWT(
      {
        'user_id': userId,
        'tenant_id': tenantId,
        'role': role,
        'type': 'access',
      },
      issuer: AppConstants.jwtIssuer,
    );

    return jwt.sign(
      SecretKey(_secret),
      expiresIn: AppConstants.accessTokenDuration,
    );
  }

  String generateRefreshToken({
    required String userId,
    required String tenantId,
  }) {
    final jwt = JWT(
      {
        'user_id': userId,
        'tenant_id': tenantId,
        'type': 'refresh',
      },
      issuer: AppConstants.jwtIssuer,
    );

    return jwt.sign(
      SecretKey(_secret),
      expiresIn: AppConstants.refreshTokenDuration,
    );
  }

  Map<String, dynamic>? verifyToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_secret));
      return jwt.payload as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

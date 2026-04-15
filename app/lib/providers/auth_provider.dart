import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../data/api/auth_api.dart';
import '../services/auth_token_service.dart';

class AuthState {
  const AuthState({
    this.isLoggedIn = false,
    this.user,
    this.isLoading = false,
    this.error,
  });

  final bool isLoggedIn;
  final Map<String, dynamic>? user;
  final bool isLoading;
  final String? error;

  String get role => user?['role'] as String? ?? 'operator';
  bool get isSuperAdmin => role == 'super_admin';
  bool get isTenantAdmin => role == 'tenant_admin' || isSuperAdmin;

  AuthState copyWith({
    bool? isLoggedIn,
    Map<String, dynamic>? user,
    bool? isLoading,
    String? error,
  }) =>
      AuthState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier()
      : super(
          AuthState(
            isLoggedIn: AuthTokenService.instance.hasToken,
            isLoading: AuthTokenService.instance.hasToken,
          ),
        ) {
    _restoreSession();
  }

  final _api = AuthApi();

  Future<void> _restoreSession() async {
    if (!AuthTokenService.instance.hasToken) return;

    try {
      final user = await _api.me();
      state = AuthState(
        isLoggedIn: true,
        user: user,
      );
    } catch (e) {
      debugPrint('[Auth] Session restore failed: $e');
      await AuthTokenService.instance.clear();
      state = const AuthState();
    }
  }

  Future<void> login({
    required String tenantSlug,
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    // Try real API first.
    try {
      final result = await _api.login(
        tenantSlug: tenantSlug,
        username: username,
        password: password,
      );

      await AuthTokenService.instance.saveTokens(
        accessToken: result['access_token'] as String,
        refreshToken: result['refresh_token'] as String,
      );

      debugPrint('[Auth] Server login success');
      state = AuthState(
        isLoggedIn: true,
        user: result['user'] as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[Auth] Server login failed: $e');

      if (ApiConstants.enableDemoMode &&
          tenantSlug == 'system' &&
          username == 'admin' &&
          password == 'admin123') {
        state = const AuthState(
          isLoggedIn: true,
          user: {
            'id': 'demo-super-admin',
            'tenant_id': 'system-uuid',
            'username': 'admin',
            'role': 'super_admin',
            'is_active': true,
          },
        );
        return;
      }

      if (ApiConstants.enableDemoMode &&
          password.length >= 6 &&
          username.isNotEmpty &&
          tenantSlug.isNotEmpty) {
        // Demo: any valid-looking credentials → tenant_admin
        state = AuthState(
          isLoggedIn: true,
          user: {
            'id': 'demo-${DateTime.now().millisecondsSinceEpoch}',
            'tenant_id': 'tenant-$tenantSlug',
            'username': username,
            'role': 'tenant_admin',
            'is_active': true,
          },
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        error:
            'Нэвтрэх боломжгүй байна. Серверийн холболт болон нэвтрэх мэдээллээ шалгана уу.',
      );
    }
  }

  Future<void> logout() async {
    final refreshToken = AuthTokenService.instance.refreshToken;
    if (refreshToken != null) {
      try {
        await _api.logout(refreshToken);
      } catch (_) {}
    }
    await AuthTokenService.instance.clear();
    state = const AuthState();
  }

  Future<void> loadUser() async {
    try {
      final user = await _api.me();
      state = state.copyWith(
        isLoggedIn: true,
        user: user,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[Auth] loadUser failed: $e');
      await AuthTokenService.instance.clear();
      state = const AuthState();
    }
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

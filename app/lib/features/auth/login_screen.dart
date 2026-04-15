import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_strings.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/ui_forms.dart';
import '../../widgets/ui_surfaces.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _tenantController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _tenantController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_tenantController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      return;
    }

    await ref.read(authStateProvider.notifier).login(
          tenantSlug: _tenantController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE6F5EE),
              Color(0xFFF4F7F2),
              Color(0xFFF6ECD8),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 820;
                    return Wrap(
                      spacing: 24,
                      runSpacing: 24,
                      children: [
                        SizedBox(
                          width: compact ? constraints.maxWidth : 430,
                          child: _LoginHero(compact: compact),
                        ),
                        SizedBox(
                          width: compact ? constraints.maxWidth : 470,
                          child: _LoginPanel(
                            tenantController: _tenantController,
                            usernameController: _usernameController,
                            passwordController: _passwordController,
                            obscurePassword: _obscurePassword,
                            error: authState.error,
                            busy: authState.isLoading,
                            onTogglePassword: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            onLogin: _login,
                            showDemo: ApiConstants.enableDemoMode,
                            onFillSuperAdmin: () {
                              setState(() {
                                _tenantController.text = 'system';
                                _usernameController.text = 'admin';
                                _passwordController.text = 'admin123';
                              });
                            },
                            onFillOperator: () {
                              setState(() {
                                _tenantController.text = 'demo';
                                _usernameController.text = 'operator';
                                _passwordController.text = 'demo123';
                              });
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 24 : 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F6C5A),
            Color(0xFF173B61),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withAlpha(40),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(24),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Image.asset('assets/icon/icon.png'),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Barcode operations\nwithout friction.',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  height: 1.02,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Multi-tenant scan workflow, task control, sync discipline, and admin oversight in a single operational surface.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withAlpha(210),
                ),
          ),
          const SizedBox(height: 26),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _HeroBadge(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Fast Capture',
              ),
              _HeroBadge(
                icon: Icons.cloud_sync_outlined,
                label: 'Sync Aware',
              ),
              _HeroBadge(
                icon: Icons.apartment_rounded,
                label: 'Multi Tenant',
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withAlpha(26)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ideal for',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 10),
                _heroRow('Warehouse and inventory scanning'),
                _heroRow('Field collection and audit workflows'),
                _heroRow('Tenant-based operational oversight'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFFFFD17A), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.tenantController,
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.error,
    required this.busy,
    required this.onTogglePassword,
    required this.onLogin,
    required this.showDemo,
    required this.onFillSuperAdmin,
    required this.onFillOperator,
  });

  final TextEditingController tenantController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final String? error;
  final bool busy;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;
  final bool showDemo;
  final VoidCallback onFillSuperAdmin;
  final VoidCallback onFillOperator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppFormPanel(
      title: S.login,
      subtitle: 'Tenant context, user identity, and secure session entry.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Access Point', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              AppInfoPill(icon: Icons.lock_outline, label: 'Secure session'),
              AppInfoPill(icon: Icons.apartment, label: 'Tenant scoped'),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: tenantController,
            decoration: InputDecoration(
              labelText: S.tenantSlug,
              prefixIcon: const Icon(Icons.apartment_rounded),
              hintText: 'system',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: usernameController,
            decoration: InputDecoration(
              labelText: S.username,
              prefixIcon: const Icon(Icons.person_rounded),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            decoration: InputDecoration(
              labelText: S.password,
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: onTogglePassword,
              ),
            ),
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onLogin(),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: AppInlineBanner(
                key: ValueKey(error),
                message: error!,
                error: true,
              ),
            ),
          ],
          const SizedBox(height: 22),
          PrimaryButton(
            label: busy ? 'Нэвтэрч байна...' : S.login,
            leadingIcon: Icons.login_rounded,
            onPressed: onLogin,
            busy: busy,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(110),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Security note', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'Production mode дээр demo fallback хаалттай. Backend session болон tenant credential шаардлагатай.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (showDemo) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha(120),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Demo quick fill', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onFillSuperAdmin,
                          icon: const Icon(Icons.shield_rounded),
                          label: const Text('Super Admin'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onFillOperator,
                          icon: const Icon(Icons.badge_outlined),
                          label: const Text('Operator'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

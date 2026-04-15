import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/ui_forms.dart';
import '../../widgets/ui_surfaces.dart';

class CreateTenantScreen extends ConsumerStatefulWidget {
  const CreateTenantScreen({super.key});

  @override
  ConsumerState<CreateTenantScreen> createState() => _CreateTenantScreenState();
}

class _CreateTenantScreenState extends ConsumerState<CreateTenantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _adminUsernameController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  bool _autoSlug = true;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _adminUsernameController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    if (_autoSlug) {
      _slugController.text = value
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '-')
          .replaceAll(RegExp(r'-+'), '-');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final tenant = await ref.read(tenantsProvider.notifier).addTenant(
            name: _nameController.text.trim(),
            slug: _slugController.text.trim(),
            adminUsername: _adminUsernameController.text.trim(),
            adminPassword: _adminPasswordController.text,
          );
      ref.read(activeTenantProvider.notifier).state = tenant;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('"${_nameController.text.trim()}" амжилттай бүртгэгдлээ')),
      );
      context.go('/tenant/${tenant.slug}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Байгууллага үүсгэж чадсангүй: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/super-admin'),
        ),
        title: const Text('Tenant Launch'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF5F0), Color(0xFFF4F7F2)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 840;
                  return Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    children: [
                      SizedBox(
                        width: compact ? constraints.maxWidth : 360,
                        child: _CreateTenantHero(),
                      ),
                      SizedBox(
                        width: compact ? constraints.maxWidth : 560,
                        child: _CreateTenantForm(
                          formKey: _formKey,
                          nameController: _nameController,
                          slugController: _slugController,
                          adminUsernameController: _adminUsernameController,
                          adminPasswordController: _adminPasswordController,
                          submitting: _submitting,
                          onNameChanged: _onNameChanged,
                          onSlugEdited: () => _autoSlug = false,
                          onSubmit: _submit,
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
    );
  }
}

class _CreateTenantHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF173B61), Color(0xFF0F6C5A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Launch a new\noperating tenant.',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Identity, admin credentials, and first access path are created in one flow.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 22),
          const AppInfoPill(
            icon: Icons.tag,
            label: 'Unique tenant slug',
            inverse: true,
          ),
          const SizedBox(height: 10),
          const AppInfoPill(
            icon: Icons.admin_panel_settings,
            label: 'First admin provisioned',
            inverse: true,
          ),
          const SizedBox(height: 10),
          const AppInfoPill(
            icon: Icons.rocket_launch_outlined,
            label: 'Ready for ops',
            inverse: true,
          ),
        ],
      ),
    );
  }
}

class _CreateTenantForm extends StatelessWidget {
  const _CreateTenantForm({
    required this.formKey,
    required this.nameController,
    required this.slugController,
    required this.adminUsernameController,
    required this.adminPasswordController,
    required this.submitting,
    required this.onNameChanged,
    required this.onSlugEdited,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController slugController;
  final TextEditingController adminUsernameController;
  final TextEditingController adminPasswordController;
  final bool submitting;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onSlugEdited;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AppFormPanel(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppFormSection(
              title: 'Tenant Identity',
              subtitle: 'Login routing and organization identity.',
              child: Column(
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Байгууллагын нэр',
                      prefixIcon: Icon(Icons.business_center_outlined),
                    ),
                    onChanged: onNameChanged,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Нэр оруулна уу';
                      }
                      if (v.length > 100) return 'Хэт урт байна';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: slugController,
                    decoration: const InputDecoration(
                      labelText: 'Байгууллагын код (slug)',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                      helperText: 'Жижиг үсэг, тоо, зураас',
                    ),
                    onChanged: (_) => onSlugEdited(),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Код оруулна уу';
                      }
                      if (v.length < 2) return 'Хамгийн багадаа 2 тэмдэгт';
                      if (!RegExp(r'^[a-z0-9-]+$').hasMatch(v)) {
                        return 'Зөвхөн жижиг үсэг, тоо, зураас';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            AppFormSection(
              title: 'First Admin',
              subtitle: 'Initial privileged account for this tenant.',
              child: Column(
                children: [
                  TextFormField(
                    controller: adminUsernameController,
                    decoration: const InputDecoration(
                      labelText: 'Админ нэвтрэх нэр',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Нэвтрэх нэр оруулна уу';
                      }
                      if (v.length < 3) return 'Хамгийн багадаа 3 тэмдэгт';
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
                        return 'Зөвхөн үсэг, тоо, доогуур зураас';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: adminPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Админ нууц үг',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    onFieldSubmitted: (_) => onSubmit(),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Нууц үг оруулна уу';
                      if (v.length < 6) return 'Хамгийн багадаа 6 тэмдэгт';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            PrimaryButton(
              label: submitting
                  ? 'Байгууллага бүртгэж байна...'
                  : 'Байгууллага бүртгэх',
              leadingIcon: Icons.rocket_launch_outlined,
              onPressed: submitting ? null : onSubmit,
              busy: submitting,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: submitting ? null : () => context.go('/super-admin'),
              child: Text(S.cancel),
            ),
          ],
        ),
      ),
    );
  }
}

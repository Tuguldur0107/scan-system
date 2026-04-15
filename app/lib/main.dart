import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'core/router.dart';
import 'services/auth_token_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthTokenService.instance.init();

  runApp(
    const ProviderScope(
      child: ScanSystemApp(),
    ),
  );
}

class ScanSystemApp extends ConsumerWidget {
  const ScanSystemApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Scan System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

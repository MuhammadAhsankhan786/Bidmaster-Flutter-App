import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'app/router/app_router.dart';
import 'app/theme/theme.dart';
import 'app/services/storage_service.dart';
import 'config/dev_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Safety check: Prevent auto-login in production builds
  if (kReleaseMode && AUTO_LOGIN_ENABLED) {
    throw Exception("❌ Auto-login must be disabled in production builds!");
  }
  
  // Check for existing session and auto-login
  await _checkAutoLogin();
  
  runApp(const MyApp());
}

Future<void> _checkAutoLogin() async {
  final isLoggedIn = await StorageService.isLoggedIn();
  if (isLoggedIn) {
    // Verify token is still valid by checking role
    final role = await StorageService.getUserRole();
    if (role == null) {
      // Invalid session - clear storage
      await StorageService.clearAll();
    } else if (role == 'admin') {
      // Admin should not access mobile app - clear storage
      await StorageService.clearAll();
    }
    // Token is valid - user will be redirected by router
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BidMaster',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
    );
  }
}

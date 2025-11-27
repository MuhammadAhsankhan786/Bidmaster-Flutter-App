import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'app/router/app_router.dart';
import 'app/theme/theme.dart';
import 'app/services/storage_service.dart';
import 'app/services/referral_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Error handling to prevent white screen
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
    } else {
      // In release mode, log error but don't crash
      print('❌ Flutter Error: ${details.exception}');
    }
  };
  
  // Handle platform errors
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      print('❌ Platform Error: $error');
      print('Stack: $stack');
    }
    return true; // Prevent app from crashing
  };
  
  try {
    // Initialize SharedPreferences before any navigation
    // This prevents white screen in release mode
    await SharedPreferences.getInstance();
    
    // Check for existing session and auto-login
    // Auto-login works in both debug and release mode (as per requirements)
    await _checkAutoLogin();
    
    // Initialize deep link handling for referral codes
    _initDeepLinks();
    
    runApp(const MyApp());
  } catch (e, stackTrace) {
    // Catch any initialization errors
    if (kDebugMode) {
      print('❌ Initialization Error: $e');
      print('Stack: $stackTrace');
    }
    // Still run app even if initialization fails
    runApp(const MyApp());
  }
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

/// Initialize deep link handling for referral codes
void _initDeepLinks() {
  final appLinks = AppLinks();
  
  // Handle initial link (if app was opened via deep link)
  appLinks.getInitialLink().then((Uri? uri) {
    if (uri != null) {
      ReferralService.handleDeepLink(uri.toString());
    }
  }).catchError((err) {
    if (kDebugMode) {
      print('❌ Error getting initial link: $err');
    }
  });

  // Handle links while app is running
  appLinks.uriLinkStream.listen((Uri uri) {
    if (uri != null) {
      ReferralService.handleDeepLink(uri.toString());
    }
  }, onError: (err) {
    if (kDebugMode) {
      print('❌ Error listening to links: $err');
    }
  });
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

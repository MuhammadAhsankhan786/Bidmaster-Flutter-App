import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/role_selection_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/buyer_dashboard_screen.dart';
import '../screens/product_details_screen.dart';
import '../screens/seller_dashboard_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/product_creation_screen.dart';
import '../services/storage_service.dart';

/// Application router configuration
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) async {
      final isLoggedIn = await StorageService.isLoggedIn();
      final location = state.uri.path;

      // Public routes - no auth required
      if (location == '/splash' || location == '/onboarding' || location == '/auth') {
        return null;
      }

      // Role selection and profile setup - accessible after OTP verification
      // Allow these routes without role checks (user might be selecting role)
      if (location == '/role-selection' || location == '/profile-setup') {
        // Only check if user is logged in, don't check role
        if (!isLoggedIn) {
          return '/auth';
        }
        return null; // Allow navigation to role-selection and profile-setup
      }

      // Protected routes - require authentication
      if (!isLoggedIn) {
        return '/auth';
      }

      // Get user role
      final role = await StorageService.getUserRole();

      // Admin blocked from mobile app (only 'admin', not 'superadmin'/'moderator'/'viewer')
      if (role == 'admin') {
        await StorageService.clearAll();
        return '/auth';
      }
      
      // Allow admin roles (superadmin, moderator, viewer) to access role-selection
      // They might want to switch to buyer/seller role
      if (role == 'superadmin' || role == 'moderator' || role == 'viewer') {
        // Allow access to role-selection and profile-setup
        if (location == '/role-selection' || location == '/profile-setup') {
          return null;
        }
        // For admin roles trying to access buyer/seller routes, redirect to role-selection
        if (location.startsWith('/home') || location.startsWith('/seller-dashboard')) {
          return '/role-selection';
        }
      }

      // Buyer routes
      if (location.startsWith('/home') || location.startsWith('/product-details')) {
        if (role != 'buyer') {
          // Redirect to appropriate dashboard
          return role == 'seller' ? '/seller-dashboard' : '/role-selection';
        }
      }

      // Seller routes
      if (location.startsWith('/seller-dashboard') || location == '/product-create') {
        if (role != 'seller') {
          // Redirect to appropriate dashboard
          return role == 'buyer' ? '/home' : '/role-selection';
        }
      }

      // Notifications - accessible to both buyer and seller
      if (location == '/notifications') {
        if (role != 'buyer' && role != 'seller') {
          return '/auth';
        }
      }

      return null; // Allow navigation
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/role-selection',
        name: 'role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        name: 'profile-setup',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          return ProfileSetupScreen(userRole: args?['role'] as String? ?? 'buyer');
        },
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const BuyerDashboardScreen(),
      ),
      GoRoute(
        path: '/product-details/:id',
        name: 'product-details',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '1';
          return ProductDetailsScreen(productId: id);
        },
      ),
      GoRoute(
        path: '/seller-dashboard',
        name: 'seller-dashboard',
        builder: (context, state) => const SellerDashboardScreen(),
      ),
      GoRoute(
        path: '/product-create',
        name: 'product-create',
        builder: (context, state) => const ProductCreationScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  );
}


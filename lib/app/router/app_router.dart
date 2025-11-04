import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/role_selection_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/buyer_dashboard_screen.dart';
import '../screens/product_details_screen.dart';
import '../screens/place_bid_modal.dart';
import '../screens/seller_dashboard_screen.dart';

/// Application router configuration
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
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
    ],
  );
}


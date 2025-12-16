import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import '../screens/splash_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/role_selection_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/buyer_dashboard_screen.dart';
import '../screens/home_screen.dart';
import '../screens/product_details_screen.dart';
import '../screens/seller_dashboard_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/product_creation_screen.dart';
import '../screens/invite_and_earn_screen.dart';
import '../screens/wallet_screen.dart';
import '../screens/buyer_bidding_history_screen.dart';
import '../screens/seller_earnings_screen.dart';
import '../screens/seller_winner_details_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/wishlist_screen.dart';
import '../screens/wins_screen.dart';
import '../screens/terms_and_conditions_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../models/product_model.dart';
import '../services/storage_service.dart';

/// Application router configuration
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) async {
      final isLoggedIn = await StorageService.isLoggedIn();
      final location = state.uri.path;

      // Public routes - no auth required (users can browse)
      if (location == '/splash' || location == '/auth') {
        return null;
      }

      // Public browsing routes - home and product details (no login required)
      if (location == '/home' || location.startsWith('/product-details')) {
        return null; // Allow public access to browse
      }

      // Signup route - public access (for new user registration)
      if (location == '/signup') {
        return null; // Allow public access to signup
      }

      // Terms and Conditions and Privacy Policy - public access (no login required)
      if (location == '/terms-and-conditions' || location == '/privacy-policy') {
        return null; // Allow public access to view terms and privacy policy
      }

      // Role selection - accessible for signup flow or after OTP verification
      if (location == '/role-selection') {
        // Allow if it's signup mode (mode=signup query parameter)
        final uri = state.uri;
        if (uri.queryParameters['mode'] == 'signup') {
          return null; // Allow signup flow
        }
        // Check if user has phone or role saved (indicates they've logged in before)
        final phone = await StorageService.getUserPhone();
        final role = await StorageService.getUserRole();
        if (phone == null && !isLoggedIn) {
          return '/auth';
        }
        return null; // Allow navigation to role-selection
      }

      // Protected routes - require authentication
      final savedPhone = await StorageService.getUserPhone();
      final savedRole = await StorageService.getUserRole();
      if (!isLoggedIn && savedPhone == null && savedRole == null) {
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
      if (role == 'superadmin' || role == 'moderator' || role == 'viewer') {
        if (location == '/role-selection') {
          return null;
        }
        // For admin roles trying to access company_products/seller_products routes, redirect to role-selection
        if (location.startsWith('/home') || location.startsWith('/seller-dashboard')) {
          return '/role-selection';
        }
      }

      // Seller Products routes
      if (location.startsWith('/seller-dashboard') || location == '/product-create') {
        if (role != 'seller_products') {
          // Redirect to appropriate dashboard
          return role == 'company_products' ? '/home' : '/role-selection';
        }
      }

      // Notifications - accessible to both company_products and seller_products
      if (location == '/notifications') {
        if (role != 'company_products' && role != 'seller_products') {
          return '/auth';
        }
      }

      // Wallet - accessible to both company_products and seller_products
      if (location == '/wallet') {
        // Check if user is logged in
        if (!isLoggedIn) {
          return '/auth';
        }
        // Allow access - wallet screen will handle role validation and show appropriate error
        // Don't block navigation based on role in router
        return null;
      }

      // Profile - accessible to both company_products and seller_products
      if (location == '/profile') {
        if (role != 'company_products' && role != 'seller_products') {
          return '/auth';
        }
      }

      // Company Products routes - My Bids, Wishlist, Wins
      if (location == '/buyer/bidding-history' || location == '/buyer-bidding-history' ||
          location == '/wishlist' || location == '/wins') {
        if (role != 'company_products') {
          return role == 'seller_products' ? '/seller-dashboard' : '/role-selection';
        }
      }

      // Seller Products routes
      if (location == '/seller/earnings' || location.startsWith('/seller/winner/')) {
        if (role != 'seller_products') {
          return role == 'company_products' ? '/home' : '/role-selection';
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
        path: '/signup',
        name: 'signup',
        builder: (context, state) {
          final role = state.uri.queryParameters['role'];
          return SignupScreen(selectedRole: role);
        },
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => HomeScreen(),
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
        builder: (context, state) {
          final product = state.extra as ProductModel?;
          return ProductCreationScreen(productToEdit: product);
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/invite-and-earn',
        name: 'invite-and-earn',
        builder: (context, state) => const InviteAndEarnScreen(),
      ),
      GoRoute(
        path: '/wallet',
        name: 'wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) {
          // Check if scrollToSettings query parameter is present
          final scrollToSettings = state.uri.queryParameters['scrollToSettings'] == 'true';
          return ProfileScreen(scrollToSettings: scrollToSettings);
        },
      ),
      GoRoute(
        path: '/buyer/bidding-history',
        name: 'buyer-bidding-history',
        builder: (context, state) => const BuyerBiddingHistoryScreen(),
      ),
      // Alias route for /buyer-bidding-history (hyphen format)
      GoRoute(
        path: '/buyer-bidding-history',
        name: 'buyer-bidding-history-alias',
        redirect: (context, state) => '/buyer/bidding-history',
      ),
      GoRoute(
        path: '/seller/earnings',
        name: 'seller-earnings',
        builder: (context, state) => const SellerEarningsScreen(),
      ),
      GoRoute(
        path: '/seller/winner/:productId',
        name: 'seller-winner-details',
        builder: (context, state) {
          final productId = state.pathParameters['productId'] ?? '1';
          return SellerWinnerDetailsScreen(productId: productId);
        },
      ),
      GoRoute(
        path: '/wishlist',
        name: 'wishlist',
        builder: (context, state) => const WishlistScreen(),
      ),
      GoRoute(
        path: '/wins',
        name: 'wins',
        builder: (context, state) => const WinsScreen(),
      ),
      GoRoute(
        path: '/terms-and-conditions',
        name: 'terms-and-conditions',
        builder: (context, state) => const TermsAndConditionsScreen(),
      ),
      GoRoute(
        path: '/privacy-policy',
        name: 'privacy-policy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
    ],
  );
}


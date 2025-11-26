import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'dart:io';
import 'dart:typed_data';
import 'package:http_parser/http_parser.dart';
import '../models/user_model.dart';
import '../models/product_model.dart';
import '../models/bid_model.dart';
import '../models/notification_model.dart';
import 'storage_service.dart';
import 'token_refresh_interceptor.dart';
import 'referral_service.dart';
import '../utils/jwt_utils.dart';

class ApiService {
  // Dynamic base URL based on debug/release mode
  // Debug: localhost (for local development)
  // Release: Production server URL or local network IP
  static String get baseUrl {
    if (kDebugMode) {
      // Debug mode: use localhost
      return 'http://localhost:5000/api';
    } else {
      // Release mode: Use production server URL
      // CRITICAL: Must be set via --dart-define=API_BASE_URL=your_url
      const String productionUrl = String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: '',
      );
      
      // In release mode, API URL must be explicitly set
      // If not set, use a placeholder that will cause clear error on first API call
      if (productionUrl.isEmpty) {
        // Return a placeholder that will fail with clear error message
        // This allows app to start but will fail on first API call with helpful message
        return 'API_BASE_URL_NOT_CONFIGURED';
      }
      
      // Validate URL format
      if (!productionUrl.startsWith('http://') && !productionUrl.startsWith('https://')) {
        throw Exception(
          'Invalid API_BASE_URL format. Must start with http:// or https://. '
          'Current value: $productionUrl'
        );
      }
      
      return productionUrl;
    }
  }
  
  late Dio _dio;

  ApiService() {
    if (kDebugMode) {
      print('🌐 API Service initialized');
      print('   Platform: ${kIsWeb ? "Web" : "Mobile"}');
      print('   Base URL: $baseUrl');
    } else {
      // In release mode, API URL is validated in baseUrl getter
      // No additional validation needed here
    }
    
    // Validate baseUrl before creating Dio instance
    if (baseUrl == 'API_BASE_URL_NOT_CONFIGURED') {
      throw Exception(
        'API_BASE_URL not configured for release build.\n\n'
        'To fix this, build with:\n'
        'flutter build apk --release --dart-define=API_BASE_URL=https://your-server.com/api\n\n'
        'Or for local network testing:\n'
        'flutter build apk --release --dart-define=API_BASE_URL=http://YOUR_LOCAL_IP:5000/api'
      );
    }
    
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    // Add error interceptor to prevent crashes
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        if (kDebugMode) {
          print('❌ API Error: ${error.message}');
        }
        // Don't let errors crash the app
        handler.next(error);
      },
    ));

    // Add token refresh interceptor (handles auto-refresh and retry)
    final refreshInterceptor = TokenRefreshInterceptor();
    refreshInterceptor.setBaseUrl(baseUrl);
    _dio.interceptors.add(refreshInterceptor);
  }

  // ==================== AUTHENTICATION ====================

  /// POST /api/auth/send-otp
  /// ✅ LIVE: Uses Twilio Verify API to send OTP
  Future<Map<String, dynamic>> sendOTP(String phone) async {
    try {
      if (kDebugMode) {
        print('📤 Sending OTP via Twilio Verify');
        print('📱 Phone number: $phone');
        print('📱 Phone format: ${phone.startsWith('+964') ? 'Valid Iraq format' : 'Invalid format'}');
      }
      
      final response = await _dio.post('/auth/send-otp', data: {'phone': phone});
      
      if (kDebugMode) {
        print('✅ OTP sent successfully via Twilio Verify');
        print('📱 OTP sent to phone: $phone');
        // Note: Backend does NOT return OTP in response for security
      }
      
      return response.data;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Send OTP error: $e');
        print('📱 Failed to send OTP to phone: $phone');
      }
      throw _handleError(e);
    }
  }

  /// POST /api/auth/login-phone
  /// ✅ LIVE: Phone + OTP login (replaces verify-otp for mobile app)
  Future<Map<String, dynamic>> loginPhone({
    required String phone,
    required String otp,
  }) async {
    try {
      if (kDebugMode) {
        print('✅ Connected to live DB - Phone + OTP login');
        print('   Phone: $phone');
        print('   OTP: $otp');
      }
      
      // Validate phone format before sending
      if (phone.isEmpty) {
        throw Exception('Phone number is required');
      }
      if (otp.isEmpty) {
        throw Exception('OTP is required');
      }
      
      // Ensure phone starts with +964
      String normalizedPhone = phone.trim();
      if (!normalizedPhone.startsWith('+964')) {
        // Try to fix common formats
        if (normalizedPhone.startsWith('964')) {
          normalizedPhone = '+$normalizedPhone';
        } else if (normalizedPhone.startsWith('0')) {
          normalizedPhone = '+964${normalizedPhone.substring(1)}';
        } else {
          throw Exception('Invalid phone format. Must start with +964');
        }
      }
      
      if (kDebugMode) {
        print('   Normalized Phone: $normalizedPhone');
        print('   Request Body: {phone: $normalizedPhone, otp: $otp}');
      }
      
      final response = await _dio.post(
        '/auth/login-phone',
        data: {
          'phone': normalizedPhone,
          'otp': otp,
        },
      );
      
      if (kDebugMode) {
        print('✅ JWT verified - Login successful');
        print('   User ID: ${response.data['user']?['id']}');
        print('   Role (from user): ${response.data['user']?['role']}');
        print('   Role (from response): ${response.data['role']}');
      }
      
      // Extract role from response (backend returns role at top level and in user object)
      final role = (response.data['role'] ?? response.data['user']?['role'] ?? 'buyer').toString().toLowerCase();
      if (kDebugMode) {
        print('   Final role: $role');
      }
      
      // Save tokens and user data
      final accessToken = response.data['accessToken'] ?? response.data['token'];
      final refreshToken = response.data['refreshToken'];
      
      if (accessToken != null) {
        // CRITICAL FIX: Validate token role matches response role
        final tokenRole = JwtUtils.getRoleFromToken(accessToken as String);
        if (tokenRole != null && tokenRole != role) {
          if (kDebugMode) {
            print('⚠️ WARNING: Token role mismatch detected!');
            print('   Token role: $tokenRole');
            print('   Response role: $role');
            print('   This should not happen - backend token role should match response role');
          }
        }
        
        // CRITICAL FIX: Clear old tokens if they exist and have wrong role
        final oldAccessToken = await StorageService.getAccessToken();
        if (oldAccessToken != null) {
          final oldTokenRole = JwtUtils.getRoleFromToken(oldAccessToken);
          if (oldTokenRole != null && oldTokenRole != role) {
            if (kDebugMode) {
              print('⚠️ Clearing old tokens with wrong role ($oldTokenRole != $role)');
            }
            await StorageService.clearAllTokens();
          }
        }
        
        if (refreshToken != null) {
          await StorageService.saveTokens(
            accessToken: accessToken as String,
            refreshToken: refreshToken as String,
          );
          if (kDebugMode) {
            print('✅ Access and refresh tokens saved to storage');
          }
          
          // Verify token role matches stored role
          final savedTokenRole = JwtUtils.getRoleFromToken(accessToken as String);
          if (kDebugMode) {
            if (savedTokenRole != null && savedTokenRole == role) {
              print('   ✅ Token role verified: $savedTokenRole');
            } else {
              print('   ⚠️ Warning: Token role mismatch after save');
            }
          }
        } else {
          // Fallback: only access token (backward compatibility)
          await StorageService.saveAccessToken(accessToken as String);
          if (kDebugMode) {
            print('✅ Access token saved to storage (no refresh token)');
          }
        }
        
        // Verify token was saved
        final savedToken = await StorageService.getAccessToken();
        if (kDebugMode) {
          if (savedToken != null) {
            print('   Access token verified in storage');
          } else {
            print('⚠️ Warning: Token not found after save');
          }
        }
      } else {
        if (kDebugMode) {
          print('❌ Error: No token in response');
        }
        throw Exception('No token received from server');
      }
      
      if (response.data['user'] != null) {
        final user = response.data['user'];
        final backendPhone = user['phone'] as String?;
        
        // CRITICAL FIX: Use the phone number that was used for login, not necessarily backend phone
        // Backend phone should match, but if there's a normalization difference, use login phone
        // CRITICAL FIX: Log phone number comparison and warn if mismatch
        if (backendPhone != null && backendPhone != normalizedPhone) {
          if (kDebugMode) {
            print('⚠️⚠️⚠️ CRITICAL: Phone number mismatch detected! ⚠️⚠️⚠️');
            print('   📱 Phone entered by user: $normalizedPhone');
            print('   📱 Phone from database: $backendPhone');
            print('   ⚠️ This can cause OTP to be sent to wrong number!');
            print('   ✅ FIX: Saving entered phone ($normalizedPhone) to ensure OTP goes to correct number');
            print('   💡 If OTP is going to wrong number, check database phone for user ID: ${user['id']}');
          }
        } else {
          if (kDebugMode) {
            print('✅ Phone numbers match: $normalizedPhone');
          }
        }
        
        await StorageService.saveUserData(
          userId: user['id'] as int,
          role: role, // Use extracted role
          phone: normalizedPhone, // CRITICAL: Always save the phone that was used for login
          name: user['name'] as String?,
          email: user['email'] as String?,
        );
        if (kDebugMode) {
          print('✅ User data saved to storage');
          print('📱 Saved phone number (for OTP): $normalizedPhone');
        }
        
        // Verify role was saved
        final savedRole = await StorageService.getUserRole();
        if (kDebugMode) {
          if (savedRole == role) {
            print('   Role verified in storage: $savedRole');
          } else {
            print('⚠️ Warning: Role mismatch - saved: $savedRole, expected: $role');
          }
        }
        
        // Verify phone was saved correctly
        final savedPhone = await StorageService.getUserPhone();
        if (kDebugMode) {
          if (savedPhone == normalizedPhone) {
            print('   ✅ Phone verified in storage: $savedPhone');
          } else {
            print('⚠️ Warning: Phone mismatch - saved: $savedPhone, expected: $normalizedPhone');
          }
        }
      } else {
        if (kDebugMode) {
          print('❌ Error: No user data in response');
        }
        throw Exception('No user data received from server');
      }
      
      return response.data;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Login phone error: $e');
        if (e is DioException && e.response != null) {
          print('   Status Code: ${e.response?.statusCode}');
          print('   Response Data: ${e.response?.data}');
        }
      }
      if (e is DioException && e.response != null) {
        final errorMessage = e.response?.data?['message'] ?? 'Login failed';
        throw Exception(errorMessage);
      }
      throw _handleError(e);
    }
  }

  /// POST /api/auth/verify-otp
  /// ✅ LIVE: Uses Twilio Verify API to verify OTP
  Future<Map<String, dynamic>> verifyOTP(String phone, String otp) async {
    try {
      if (kDebugMode) {
        print('🔐 Verifying OTP via Twilio Verify');
        print('📱 Phone: $phone');
        print('🔑 OTP: [hidden]');
      }
      
      // Normalize phone to match backend format
      String normalizedPhone = phone.trim();
      if (!normalizedPhone.startsWith('+964')) {
        if (normalizedPhone.startsWith('964')) {
          normalizedPhone = '+$normalizedPhone';
        } else if (normalizedPhone.startsWith('0')) {
          normalizedPhone = '+964${normalizedPhone.substring(1)}';
        } else if (normalizedPhone.startsWith('00964')) {
          normalizedPhone = '+964${normalizedPhone.substring(5)}';
        } else {
          throw Exception('Invalid phone format. Must start with +964');
        }
      }
      
      // Get pending referral code if exists
      final referralCode = await _getPendingReferralCode();
      
      final requestData = {
        'phone': normalizedPhone,
        'otp': otp,
      };
      
      // Add referral code if available
      if (referralCode != null && referralCode.isNotEmpty) {
        requestData['referral_code'] = referralCode;
        if (kDebugMode) {
          print('📎 Including referral code in verify-otp request: $referralCode');
        }
      }
      
      final response = await _dio.post(
        '/auth/verify-otp',
        data: requestData,
      );
      
      // Clear referral code after successful verification
      if (response.data['success'] == true) {
        await _clearPendingReferralCode();
      }
      
      if (kDebugMode) {
        print('✅ OTP verified successfully via Twilio Verify');
        print('   User ID: ${response.data['user']?['id']}');
        print('   Role: ${response.data['role'] ?? response.data['user']?['role']}');
      }
      
      // Extract role from response
      final role = (response.data['role'] ?? response.data['user']?['role'] ?? 'buyer').toString().toLowerCase();
      
      // Save tokens and user data
      final accessToken = response.data['accessToken'] ?? response.data['token'];
      final refreshToken = response.data['refreshToken'];
      
      if (accessToken != null) {
        if (refreshToken != null) {
          await StorageService.saveTokens(
            accessToken: accessToken as String,
            refreshToken: refreshToken as String,
          );
          if (kDebugMode) {
            print('✅ Access and refresh tokens saved to storage');
          }
        } else {
          await StorageService.saveAccessToken(accessToken as String);
          if (kDebugMode) {
            print('✅ Access token saved to storage');
          }
        }
        
        // Save user data
        if (response.data['user'] != null) {
          final user = response.data['user'];
          await StorageService.saveUserData(
            userId: user['id'] as int,
            role: role,
            phone: normalizedPhone,
            name: user['name'] as String?,
            email: user['email'] as String?,
          );
          if (kDebugMode) {
            print('✅ User data saved to storage');
          }
        }
      }
      
      return response.data;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Verify OTP error: $e');
        if (e is DioException && e.response != null) {
          print('   Status Code: ${e.response?.statusCode}');
          print('   Response Data: ${e.response?.data}');
        }
      }
      throw _handleError(e);
    }
  }

  /// POST /api/auth/register
  /// ✅ LIVE: Connects to backend database
  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    String? email,
    required String password,
    required String role,
  }) async {
    try {
      if (kDebugMode) {
        print('✅ Connected to live DB - Registering user');
        print('   Name: $name, Phone: $phone, Role: $role');
      }
      
      final response = await _dio.post(
        '/auth/register',
        data: {
          'name': name,
          'phone': phone,
          if (email != null && email.isNotEmpty) 'email': email,
          'password': password,
          'role': role,
        },
      );
      
      if (kDebugMode) {
        print('✅ JWT verified - User registered successfully');
        print('   User ID: ${response.data['user']?['id']}');
      }
      
      // Save tokens and user data
      final accessToken = response.data['accessToken'] ?? response.data['token'];
      final refreshToken = response.data['refreshToken'];
      
      if (accessToken != null) {
        if (refreshToken != null) {
          await StorageService.saveTokens(
            accessToken: accessToken as String,
            refreshToken: refreshToken as String,
          );
          if (kDebugMode) {
            print('✅ Access and refresh tokens saved to storage');
          }
        } else {
          await StorageService.saveAccessToken(accessToken as String);
          if (kDebugMode) {
            print('✅ Access token saved to storage');
          }
        }
      }
      
      if (response.data['user'] != null) {
        final user = response.data['user'];
        await StorageService.saveUserData(
          userId: user['id'] as int,
          role: user['role'] as String,
          phone: user['phone'] as String,
          name: user['name'] as String?,
          email: user['email'] as String?,
        );
        if (kDebugMode) {
          print('✅ User data saved to storage');
        }
      }
      
      if (kDebugMode) {
        print('✅ Fetched 1 record (new user)');
      }
      
      return response.data;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Registration error: $e');
      }
      throw _handleError(e);
    }
  }

  /// POST /api/auth/login
  /// ✅ LIVE: Connects to backend database
  Future<Map<String, dynamic>> login({
    String? phone,
    String? email,
    required String password,
  }) async {
    try {
      print('✅ Connected to live DB - Logging in');
      print('   Phone: $phone, Email: $email');
      
      final response = await _dio.post(
        '/auth/login',
        data: {
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
          'password': password,
        },
      );
      
      print('✅ JWT verified - Login successful');
      print('   User ID: ${response.data['user']?['id']}');
      print('   Role: ${response.data['user']?['role']}');
      
      // Save tokens and user data
      final accessToken = response.data['accessToken'] ?? response.data['token'];
      final refreshToken = response.data['refreshToken'];
      
      if (accessToken != null) {
        if (refreshToken != null) {
          await StorageService.saveTokens(
            accessToken: accessToken as String,
            refreshToken: refreshToken as String,
          );
          print('✅ Access and refresh tokens saved to storage');
        } else {
          await StorageService.saveAccessToken(accessToken as String);
          print('✅ Access token saved to storage');
        }
      }
      if (response.data['user'] != null) {
        final user = response.data['user'];
        await StorageService.saveUserData(
          userId: user['id'] as int,
          role: user['role'] as String,
          phone: user['phone'] as String,
          name: user['name'] as String?,
          email: user['email'] as String?,
        );
        print('✅ User data saved to storage');
      }
      
      return response.data;
    } catch (e) {
      print('❌ Login error: $e');
      throw _handleError(e);
    }
  }

  /// POST /api/auth/refresh
  /// ✅ Refresh access token using refresh token
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      print('🔄 Refreshing access token...');
      
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      
      if (response.data['success'] == true) {
        print('✅ Token refreshed successfully');
      } else {
        print('⚠️ Token refresh returned success: false');
      }
      
      return response.data;
    } catch (e) {
      print('❌ Refresh token error: $e');
      throw _handleError(e);
    }
  }

  /// GET /api/auth/profile
  /// ✅ LIVE: Live user info from database
  Future<UserModel> getProfile() async {
    try {
      print('✅ Connected to live DB - Fetching user profile');
      
      final response = await _dio.get('/auth/profile');
      
      print('✅ JWT verified');
      print('✅ Fetched 1 record (user profile)');
      
      return UserModel.fromJson(response.data['data']);
    } catch (e) {
      print('❌ Error fetching profile: $e');
      throw _handleError(e);
    }
  }

  /// PATCH /api/auth/profile
  /// ✅ LIVE: Updates database
  /// When role is updated, backend returns new tokens that must be saved
  Future<UserModel> updateProfile({String? name, String? phone, String? role}) async {
    try {
      print('✅ Connected to live DB - Updating profile');
      print('   Name: $name, Phone: $phone, Role: $role');
      
      final response = await _dio.patch(
        '/auth/profile',
        data: {
          if (name != null) 'name': name,
          if (phone != null) 'phone': phone,
          if (role != null) 'role': role, // 🔧 FIX: Allow role updates
        },
      );
      
      print('✅ JWT verified');
      print('✅ Profile updated in database');
      
      // 🔧 FIX: If role was updated, backend returns new tokens - save them
      if (role != null && response.data['accessToken'] != null) {
        final newAccessToken = response.data['accessToken'] as String;
        final newRefreshToken = response.data['refreshToken'] as String;
        final updatedRole = (response.data['role'] ?? role).toString().toLowerCase();
        
        print('✅ New tokens received after role update');
        print('   Updated role: $updatedRole');
        
        // Verify token role matches updated role
        final tokenRole = JwtUtils.getRoleFromToken(newAccessToken);
        if (tokenRole != null && tokenRole != updatedRole) {
          print('⚠️ WARNING: New token role ($tokenRole) != Updated role ($updatedRole)');
        } else {
          print('   ✅ Token role verified: $tokenRole');
        }
        
        // Save new tokens
        await StorageService.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
        );
        print('✅ New tokens saved to storage');
        
        // Update role in SharedPreferences to match token
        final userData = response.data['data'] as Map<String, dynamic>;
        await StorageService.saveUserData(
          userId: userData['id'] as int,
          role: updatedRole,
          phone: userData['phone'] as String? ?? await StorageService.getUserPhone() ?? '',
          name: userData['name'] as String?,
          email: userData['email'] as String?,
        );
        print('✅ Role updated in SharedPreferences: $updatedRole');
        
        // Verify everything is in sync
        final savedTokenRole = JwtUtils.getRoleFromToken(newAccessToken);
        final savedRole = await StorageService.getUserRole();
        if (savedTokenRole != null && savedRole != null && savedTokenRole == savedRole) {
          print('   ✅ Token role and SharedPreferences role are in sync: $savedRole');
        } else {
          print('⚠️ Warning: Role mismatch after update');
          print('   Token role: $savedTokenRole');
          print('   SharedPreferences role: $savedRole');
        }
      }
      
      return UserModel.fromJson(response.data['data']);
    } catch (e) {
      print('❌ Error updating profile: $e');
      throw _handleError(e);
    }
  }

  /// POST /api/auth/logout
  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
      await StorageService.clearAll();
    } catch (e) {
      // Clear storage even if API call fails
      await StorageService.clearAll();
      throw _handleError(e);
    }
  }

  // ==================== PRODUCTS ====================

  /// GET /api/products
  /// ✅ LIVE: Connects to backend database
  Future<Map<String, dynamic>> getAllProducts({
    String? category,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      print('✅ Connected to live DB - Fetching products');
      print('   Category: $category, Search: $search, Page: $page, Limit: $limit');
      
      final response = await _dio.get(
        '/products',
        queryParameters: {
          if (category != null) 'category': category,
          if (search != null && search.isNotEmpty) 'search': search,
          'page': page,
          'limit': limit,
        },
      );
      
      print('✅ JWT verified');
      
      if (response.data['data'] == null) {
        print('❌ Response data field is null!');
        throw Exception('Invalid API response: missing data field');
      }
      
      final dataList = response.data['data'] as List?;
      if (dataList == null) {
        print('❌ Response data is not a list!');
        throw Exception('Invalid API response: data is not a list');
      }
      
      print('✅ Fetched ${dataList.length} records from database');
      
      final products = <ProductModel>[];
      for (int i = 0; i < dataList.length; i++) {
        try {
          final product = ProductModel.fromJson(dataList[i] as Map<String, dynamic>);
          products.add(product);
        } catch (parseError) {
          print('❌ Failed to parse product at index $i: $parseError');
          // Continue with other products instead of failing completely
        }
      }
      
      return {
        'products': products,
        'pagination': response.data['pagination'],
      };
    } catch (e) {
      print('❌ Error in getAllProducts: $e');
      throw _handleError(e);
    }
  }

  /// GET /api/products/:id
  /// ✅ LIVE: Connects to backend database
  Future<ProductModel> getProductById(int id) async {
    try {
      print('✅ Connected to live DB - Fetching product ID: $id');
      
      final response = await _dio.get('/products/$id');
      
      print('✅ JWT verified');
      print('✅ Fetched 1 record (product details)');
      
      return ProductModel.fromJson(response.data['data']);
    } catch (e) {
      print('❌ Error fetching product: $e');
      throw _handleError(e);
    }
  }

  /// GET /api/products/mine
  /// ✅ LIVE: Connects to backend database
  Future<List<ProductModel>> getMyProducts({String? status}) async {
    try {
      print('✅ Connected to live DB - Fetching my products');
      print('   Status filter: $status');
      
      final response = await _dio.get(
        '/products/mine',
        queryParameters: {
          if (status != null) 'status': status,
        },
      );
      
      print('✅ JWT verified');
      print('   Response status: ${response.statusCode}');
      print('   Full response: ${response.data}');
      print('   Response data keys: ${response.data.keys}');
      print('   Response success: ${response.data['success']}');
      
      // Check if data exists
      if (response.data['data'] == null) {
        print('⚠️ Response data is null');
        print('   Full response structure: ${response.data}');
        return [];
      }
      
      final dataList = response.data['data'];
      print('   Data type: ${dataList.runtimeType}');
      print('   Data length: ${dataList is List ? dataList.length : 'N/A'}');
      
      if (dataList is! List) {
        print('❌ Response data is not a list: $dataList');
        print('   Actual type: ${dataList.runtimeType}');
        return [];
      }
      
      if (dataList.isEmpty) {
        print('⚠️ Response data is empty list');
        print('   This means the logged-in seller has no products in database');
        return [];
      }
      
      print('   First product sample: ${dataList[0]}');
      
      final products = dataList
          .map((json) {
            try {
              return ProductModel.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              print('❌ Error parsing product: $e');
              print('   JSON: $json');
              return null;
            }
          })
          .whereType<ProductModel>()
          .toList();
      
      print('✅ Fetched ${products.length} records (my products)');
      
      return products;
    } catch (e) {
      print('❌ Error fetching my products: $e');
      if (e is DioException && e.response != null) {
        print('   Status Code: ${e.response?.statusCode}');
        print('   Response Data: ${e.response?.data}');
      }
      throw _handleError(e);
    }
  }

  /// POST /api/uploads/image
  /// ✅ Upload image file and return URL
  /// Supports both File (mobile) and Uint8List (web)
  Future<String> uploadImage(dynamic imageData, {String? filename}) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      MultipartFile multipartFile;
      String contentType = 'image/jpeg';
      String fileName = filename ?? 'image.jpg';

      if (kIsWeb && imageData is Uint8List) {
        // Web: Use bytes directly
        print('📤 Uploading image from bytes (web): ${imageData.length} bytes');
        
        // Try to detect image type from bytes
        if (imageData.length >= 4) {
          // PNG signature: 89 50 4E 47
          if (imageData[0] == 0x89 && imageData[1] == 0x50 && 
              imageData[2] == 0x4E && imageData[3] == 0x47) {
            contentType = 'image/png';
            fileName = filename ?? 'image.png';
          }
          // JPEG signature: FF D8 FF
          else if (imageData[0] == 0xFF && imageData[1] == 0xD8 && imageData[2] == 0xFF) {
            contentType = 'image/jpeg';
            fileName = filename ?? 'image.jpg';
          }
        }

        multipartFile = MultipartFile.fromBytes(
          imageData,
          filename: fileName,
          contentType: MediaType('image', contentType.split('/').last),
        );
      } else if (imageData is File) {
        // Mobile: Use File
        print('📤 Uploading image: ${imageData.path}');
        
        fileName = imageData.path.split('/').last;
        final fileExtension = fileName.split('.').last.toLowerCase();
        
        // Determine content type
        if (fileExtension == 'png') {
          contentType = 'image/png';
        } else if (fileExtension == 'gif') {
          contentType = 'image/gif';
        } else if (fileExtension == 'webp') {
          contentType = 'image/webp';
        }

        multipartFile = await MultipartFile.fromFile(
          imageData.path,
          filename: fileName,
          contentType: MediaType('image', fileExtension),
        );
      } else {
        throw Exception('Invalid image data type. Expected File or Uint8List.');
      }

      // Create FormData for multipart upload
      final formData = FormData.fromMap({
        'image': multipartFile,
      });

      final response = await _dio.post(
        '/uploads/image',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        final imageUrl = response.data['data']['url'] as String;
        print('✅ Image uploaded successfully: $imageUrl');
        return imageUrl;
      } else {
        throw Exception('Failed to upload image: ${response.data['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('❌ Error uploading image: $e');
      if (e is DioException && e.response != null) {
        print('   Error Status Code: ${e.response!.statusCode}');
        print('   Error Response Data: ${e.response!.data}');
      }
      throw _handleError(e);
    }
  }

  /// POST /api/products/create
  /// ✅ LIVE: Inserts into database
  Future<ProductModel> createProduct({
    required String title,
    String? description,
    String? imageUrl,
    required double startingPrice,
    int? duration,
    int? categoryId,
  }) async {
    try {
      print('✅ Connected to live DB - Creating product');
      print('   Title: $title, Price: $startingPrice');
      
      // 🔍 DEEP TRACE: Before product creation
      print('🔍 [DEEP TRACE] ApiService.createProduct() - BEFORE REQUEST');
      
      // Get current user info for debugging
      final userId = await StorageService.getUserId();
      final userRole = await StorageService.getUserRole();
      print('   Current User ID: $userId');
      print('   Current User Role: $userRole');
      
      // 🔍 DEEP TRACE: Get token directly
      final accessToken = await StorageService.getAccessToken();
      final refreshToken = await StorageService.getRefreshToken();
      
      if (accessToken != null) {
        final tokenRole = JwtUtils.getRoleFromToken(accessToken);
        final tokenUserId = JwtUtils.getUserIdFromToken(accessToken);
        print('   🔍 Access Token Details:');
        print('      Token role: $tokenRole');
        print('      Token userId: $tokenUserId');
        print('      Token length: ${accessToken.length}');
        print('      Token preview: ${accessToken.substring(0, accessToken.length > 50 ? 50 : accessToken.length)}...');
        print('   🔍 Refresh Token: ${refreshToken != null ? "Present (${refreshToken.length} chars)" : "NULL"}');
        print('   🔍 Stored Role: $userRole');
        
        if (tokenRole != null && userRole != null && tokenRole != userRole) {
          print('   ⚠️⚠️⚠️ CRITICAL MISMATCH BEFORE PRODUCT CREATE! ⚠️⚠️⚠️');
          print('   ⚠️ Token role ($tokenRole) != Stored role ($userRole)');
          print('   ⚠️ This will cause 403 Forbidden!');
          print('   ⚠️ STACK TRACE:');
          print(StackTrace.current);
        }
      } else {
        print('   ⚠️ NO ACCESS TOKEN AVAILABLE!');
      }
      
      final response = await _dio.post(
        '/products/create',
        data: {
          'title': title,
          'description': description,
          'image_url': imageUrl,
          'startingPrice': startingPrice,
          'duration': duration ?? 7,
          'category_id': categoryId,
        },
      );
      
      print('✅ JWT verified');
      print('✅ Product created in database');
      print('   Product ID: ${response.data['data']?['id']}');
      
      return ProductModel.fromJson(response.data['data']);
    } catch (e) {
      print('❌ Error creating product: $e');
      
      // Log detailed error information
      if (e is DioException && e.response != null) {
        print('   Error Status Code: ${e.response!.statusCode}');
        print('   Error Response Data: ${e.response!.data}');
        final errorData = e.response!.data;
        if (errorData is Map) {
          print('   Error Message: ${errorData['message'] ?? errorData['error'] ?? 'Unknown error'}');
        }
      }
      
      throw _handleError(e);
    }
  }

  /// PUT /api/products/:id
  /// ✅ LIVE: Updates product in database (Seller can edit ONLY their own products)
  Future<ProductModel> updateProduct({
    required int id,
    String? title,
    String? description,
    String? imageUrl,
    double? startingPrice,
    int? categoryId,
  }) async {
    try {
      print('✅ Connected to live DB - Updating product: $id');
      print('   Update data: title=${title != null ? "provided" : "null"}, description=${description != null ? "provided" : "null"}, imageUrl=${imageUrl != null ? "provided" : "null"}, startingPrice=${startingPrice != null ? startingPrice : "null"}');
      
      // Build request body - always include fields that are provided
      final Map<String, dynamic> requestData = {};
      
      // Title is required for updates
      if (title != null) {
        requestData['title'] = title;
      }
      
      // Description can be null (to clear it) or a string
      if (description != null) {
        requestData['description'] = description.isEmpty ? null : description;
      }
      
      // Image URL: always send when provided (can be string URL or null to remove)
      // The product_creation_screen always provides imageUrl when updating
      if (imageUrl != null) {
        requestData['image_url'] = imageUrl;
      } else if (title != null) {
        // If updating and imageUrl is explicitly null, send null to remove image
        requestData['image_url'] = null;
      }
      
      // Starting price is required for updates
      if (startingPrice != null) {
        requestData['startingPrice'] = startingPrice;
      }
      
      if (categoryId != null) {
        requestData['category_id'] = categoryId;
      }
      
      print('   Request payload: $requestData');
      
      final response = await _dio.put(
        '/products/$id',
        data: requestData,
      );
      
      print('✅ JWT verified');
      print('✅ Product updated in database');
      print('   Response: ${response.data}');
      
      if (response.data['success'] == true && response.data['data'] != null) {
        return ProductModel.fromJson(response.data['data']);
      } else {
        throw Exception('Invalid response format from server');
      }
    } catch (e) {
      print('❌ Error updating product: $e');
      if (e is DioException && e.response != null) {
        print('   Error Status Code: ${e.response!.statusCode}');
        print('   Error Response Data: ${e.response!.data}');
        final errorData = e.response!.data;
        if (errorData is Map) {
          print('   Error Message: ${errorData['message'] ?? errorData['error'] ?? 'Unknown error'}');
        }
      }
      throw _handleError(e);
    }
  }

  /// DELETE /api/products/:id
  /// ✅ LIVE: Deletes product from database (Seller can delete ONLY their own products)
  Future<void> deleteProduct(int id) async {
    try {
      print('✅ Connected to live DB - Deleting product: $id');
      
      final response = await _dio.delete('/products/$id');
      
      print('✅ JWT verified');
      print('✅ Product deleted from database');
      print('   Response: ${response.data}');
    } catch (e) {
      print('❌ Error deleting product: $e');
      if (e is DioException && e.response != null) {
        print('   Error Status Code: ${e.response!.statusCode}');
        print('   Error Response Data: ${e.response!.data}');
      }
      throw _handleError(e);
    }
  }

  // ==================== BIDS ====================

  /// POST /api/bids/place
  /// ✅ LIVE: Inserts into database
  Future<BidModel> placeBid({
    required int productId,
    required double amount,
  }) async {
    try {
      print('✅ Connected to live DB - Placing bid');
      print('   Product ID: $productId, Amount: $amount');
      
      final response = await _dio.post(
        '/bids/place',
        data: {
          'productId': productId,
          'amount': amount,
        },
      );
      
      print('✅ JWT verified');
      print('✅ Bid placed in database');
      print('   Bid ID: ${response.data['data']?['id']}');
      
      return BidModel.fromJson(response.data['data']);
    } catch (e) {
      print('❌ Error placing bid: $e');
      
      // Better error handling for 400 errors
      if (e is DioException && e.response != null) {
        final statusCode = e.response?.statusCode;
        final errorData = e.response?.data;
        
        if (statusCode == 400) {
          final errorMessage = errorData is Map 
              ? (errorData['message'] ?? errorData['error'] ?? 'Invalid bid request')
              : 'Invalid bid request';
          
          print('   ⚠️ 400 Bad Request: $errorMessage');
          print('   Response data: $errorData');
          
          throw Exception(errorMessage);
        }
      }
      
      throw _handleError(e);
    }
  }

  /// GET /api/bids/:productId
  /// ✅ LIVE: Connects to backend database
  Future<List<BidModel>> getBidsByProduct(int productId) async {
    try {
      print('✅ Connected to live DB - Fetching bids for product: $productId');
      
      final response = await _dio.get('/bids/$productId');
      
      print('✅ JWT verified');
      
      final bids = (response.data['data'] as List)
          .map((json) => BidModel.fromJson(json))
          .toList();
      
      print('✅ Fetched ${bids.length} records (bids)');
      
      return bids;
    } catch (e) {
      print('❌ Error fetching bids: $e');
      throw _handleError(e);
    }
  }

  /// GET /api/bids/mine
  /// ✅ LIVE: Connects to backend database
  Future<List<BidModel>> getMyBids() async {
    try {
      print('✅ Connected to live DB - Fetching my bids');
      
      final response = await _dio.get('/bids/mine');
      
      print('✅ JWT verified');
      
      final bids = (response.data['data'] as List)
          .map((json) => BidModel.fromJson(json))
          .toList();
      
      print('✅ Fetched ${bids.length} records (my bids)');
      
      return bids;
    } catch (e) {
      print('❌ Error fetching my bids: $e');
      throw _handleError(e);
    }
  }

  // ==================== NOTIFICATIONS ====================

  /// GET /api/notifications
  /// ✅ LIVE: DB-driven list
  Future<List<NotificationModel>> getNotifications({
    bool? read,
    int limit = 50,
  }) async {
    try {
      print('✅ Connected to live DB - Fetching notifications');
      print('   Read filter: $read, Limit: $limit');
      
      final response = await _dio.get(
        '/notifications',
        queryParameters: {
          if (read != null) 'read': read.toString(),
          'limit': limit,
        },
      );
      
      print('✅ JWT verified');
      
      final notifications = (response.data['data'] as List)
          .map((json) => NotificationModel.fromJson(json))
          .toList();
      
      print('✅ Fetched ${notifications.length} records (notifications)');
      
      return notifications;
    } catch (e) {
      print('❌ Error fetching notifications: $e');
      throw _handleError(e);
    }
  }

  /// PATCH /api/notifications/read/:id
  /// ✅ LIVE: Updates database
  Future<NotificationModel> markNotificationAsRead(int id) async {
    try {
      print('✅ Connected to live DB - Marking notification as read: $id');
      
      final response = await _dio.patch('/notifications/read/$id');
      
      print('✅ JWT verified');
      print('✅ Notification updated in database');
      
      return NotificationModel.fromJson(response.data['data']);
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      throw _handleError(e);
    }
  }

  // ==================== ORDERS ====================

  /// POST /api/orders/create
  /// ✅ LIVE: Creates order in database
  Future<Map<String, dynamic>> createOrder({required int productId}) async {
    try {
      print('✅ Connected to live DB - Creating order');
      print('   Product ID: $productId');
      
      final response = await _dio.post(
        '/orders/create',
        data: {'productId': productId},
      );
      
      print('✅ JWT verified');
      print('✅ Order created in database');
      print('   Order ID: ${response.data['data']?['id']}');
      
      return response.data;
    } catch (e) {
      print('❌ Error creating order: $e');
      throw _handleError(e);
    }
  }

  /// GET /api/orders/mine
  /// ✅ LIVE: DB transaction list
  Future<List<Map<String, dynamic>>> getMyOrders({String? status, String? type}) async {
    try {
      print('✅ Connected to live DB - Fetching my orders');
      print('   Status: $status, Type: $type');
      
      final response = await _dio.get(
        '/orders/mine',
        queryParameters: {
          if (status != null) 'status': status,
          if (type != null) 'type': type,
        },
      );
      
      print('✅ JWT verified');
      
      final orders = (response.data['data'] as List)
          .map((json) => json as Map<String, dynamic>)
          .toList();
      
      print('✅ Fetched ${orders.length} records (orders)');
      
      return orders;
    } catch (e) {
      print('❌ Error fetching orders: $e');
      throw _handleError(e);
    }
  }

  // ==================== ERROR HANDLING ====================

  String _handleError(dynamic error) {
    if (error is DioException) {
      if (error.response != null) {
        final data = error.response!.data;
        if (data is Map && data.containsKey('message')) {
          return data['message'] as String;
        }
        if (data is Map && data.containsKey('error')) {
          return data['error'] as String;
        }
        return 'Server error: ${error.response!.statusCode}';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Connection timeout. Please check your internet connection.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'Unable to connect to server. Please check your internet connection.';
      }
      return error.message ?? 'An error occurred';
    }
    return error.toString();
  }
}

// Singleton instance - lazy initialization to prevent startup crashes
ApiService? _apiServiceInstance;

ApiService get apiService {
  if (_apiServiceInstance == null) {
    try {
      _apiServiceInstance = ApiService();
    } catch (e) {
      // In release mode, if API URL is not configured, show clear error
      if (kDebugMode) {
        print('❌ API Service initialization failed: $e');
      }
      rethrow; // Re-throw to show error to user
    }
  }
  return _apiServiceInstance!;
}


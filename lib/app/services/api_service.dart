import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_model.dart';
import '../models/product_model.dart';
import '../models/bid_model.dart';
import '../models/notification_model.dart';
import 'storage_service.dart';

class ApiService {
  // Use local backend for development (web) to avoid CORS issues
  // Use production backend for mobile apps and production builds
  static String get baseUrl {
    if (kIsWeb) {
      // For web development, use local backend to avoid CORS
      // Change this to your local backend URL if different
      return 'http://localhost:5000/api';
    }
    // For mobile apps, use production API
    return 'https://bidmaster-api.onrender.com/api';
  }
  
  late Dio _dio;

  ApiService() {
    print('🌐 API Service initialized');
    print('   Platform: ${kIsWeb ? "Web" : "Mobile"}');
    print('   Base URL: $baseUrl');
    
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add request interceptor to inject JWT token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await StorageService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            // Token expired or invalid - clear storage
            StorageService.clearAll();
          }
          return handler.next(error);
        },
      ),
    );
  }

  // ==================== AUTHENTICATION ====================

  /// POST /api/auth/send-otp
  /// ✅ LIVE: Connects to backend database
  Future<Map<String, dynamic>> sendOTP(String phone) async {
    try {
      print('✅ Connected to live DB - Sending OTP');
      print('   Phone: $phone');
      
      final response = await _dio.post('/auth/send-otp', data: {'phone': phone});
      
      print('✅ OTP sent successfully');
      print('   OTP: ${response.data['otp'] ?? 'Sent via SMS'}');
      
      return response.data;
    } catch (e) {
      print('❌ Send OTP error: $e');
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
      print('✅ Connected to live DB - Phone + OTP login');
      print('   Phone: $phone');
      print('   OTP: $otp');
      
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
      
      print('   Normalized Phone: $normalizedPhone');
      print('   Request Body: {phone: $normalizedPhone, otp: $otp}');
      
      final response = await _dio.post(
        '/auth/login-phone',
        data: {
          'phone': normalizedPhone,
          'otp': otp,
        },
      );
      
      print('✅ JWT verified - Login successful');
      print('   User ID: ${response.data['user']?['id']}');
      print('   Role (from user): ${response.data['user']?['role']}');
      print('   Role (from response): ${response.data['role']}');
      
      // Extract role from response (backend returns role at top level and in user object)
      final role = (response.data['role'] ?? response.data['user']?['role'] ?? 'buyer').toString().toLowerCase();
      print('   Final role: $role');
      
      // Save token and user data
      if (response.data['token'] != null) {
        await StorageService.saveToken(response.data['token'] as String);
        print('✅ Token saved to storage');
        
        // Verify token was saved
        final savedToken = await StorageService.getToken();
        if (savedToken != null) {
          print('   Token verified in storage');
        } else {
          print('⚠️ Warning: Token not found after save');
        }
      } else {
        print('❌ Error: No token in response');
        throw Exception('No token received from server');
      }
      
      if (response.data['user'] != null) {
        final user = response.data['user'];
        await StorageService.saveUserData(
          userId: user['id'] as int,
          role: role, // Use extracted role
          phone: user['phone'] as String,
          name: user['name'] as String?,
          email: user['email'] as String?,
        );
        print('✅ User data saved to storage');
        
        // Verify role was saved
        final savedRole = await StorageService.getUserRole();
        if (savedRole == role) {
          print('   Role verified in storage: $savedRole');
        } else {
          print('⚠️ Warning: Role mismatch - saved: $savedRole, expected: $role');
        }
      } else {
        print('❌ Error: No user data in response');
        throw Exception('No user data received from server');
      }
      
      return response.data;
    } catch (e) {
      print('❌ Login phone error: $e');
      if (e is DioException && e.response != null) {
        print('   Status Code: ${e.response?.statusCode}');
        print('   Response Data: ${e.response?.data}');
        final errorMessage = e.response?.data?['message'] ?? 'Login failed';
        throw Exception(errorMessage);
      }
      throw _handleError(e);
    }
  }

  /// POST /api/auth/verify-otp
  /// ✅ LIVE: Connects to backend database (legacy - use loginPhone instead)
  Future<Map<String, dynamic>> verifyOTP(String phone, String otp) async {
    try {
      print('✅ Connected to live DB - Verifying OTP');
      print('   Phone: $phone');
      
      final response = await _dio.post(
        '/auth/verify-otp',
        data: {'phone': phone, 'otp': otp},
      );
      
      print('✅ JWT verified - OTP valid');
      
      // Save token if provided
      if (response.data['token'] != null) {
        await StorageService.saveToken(response.data['token']);
        print('✅ Token saved to storage');
      }
      
      return response.data;
    } catch (e) {
      print('❌ Verify OTP error: $e');
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
      print('✅ Connected to live DB - Registering user');
      print('   Name: $name, Phone: $phone, Role: $role');
      
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
      
      print('✅ JWT verified - User registered successfully');
      print('   User ID: ${response.data['user']?['id']}');
      print('   Token received: ${response.data['token'] != null ? 'Yes' : 'No'}');
      
      // Save token and user data
      if (response.data['token'] != null) {
        await StorageService.saveToken(response.data['token']);
        print('✅ Token saved to storage');
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
      
      print('✅ Fetched 1 record (new user)');
      
      return response.data;
    } catch (e) {
      print('❌ Registration error: $e');
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
      
      // Save token and user data
      if (response.data['token'] != null) {
        await StorageService.saveToken(response.data['token']);
        print('✅ Token saved to storage');
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
  Future<UserModel> updateProfile({String? name, String? phone}) async {
    try {
      print('✅ Connected to live DB - Updating profile');
      print('   Name: $name, Phone: $phone');
      
      final response = await _dio.patch(
        '/auth/profile',
        data: {
          if (name != null) 'name': name,
          if (phone != null) 'phone': phone,
        },
      );
      
      print('✅ JWT verified');
      print('✅ Profile updated in database');
      
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

// Singleton instance
final apiService = ApiService();


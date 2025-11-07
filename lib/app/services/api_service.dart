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
  Future<Map<String, dynamic>> sendOTP(String phone) async {
    try {
      final response = await _dio.post('/auth/send-otp', data: {'phone': phone});
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// POST /api/auth/verify-otp
  Future<Map<String, dynamic>> verifyOTP(String phone, String otp) async {
    try {
      final response = await _dio.post(
        '/auth/verify-otp',
        data: {'phone': phone, 'otp': otp},
      );
      
      // Save token if provided
      if (response.data['token'] != null) {
        await StorageService.saveToken(response.data['token']);
      }
      
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// POST /api/auth/register
  /// MOCKED: Returns fake 200 success with dummy data (CORS safe)
  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    String? email,
    required String password,
    required String role,
  }) async {
    // Mock register API call - skip real backend call
    print('🔧 Mock register used (CORS safe) - Skipping POST /api/auth/register');
    
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Generate mock response matching backend structure
    final mockUserId = DateTime.now().millisecondsSinceEpoch % 100000;
    final mockToken = 'mock_token_${mockUserId}_${DateTime.now().millisecondsSinceEpoch}';
    
    final mockResponse = {
      'token': mockToken,
      'user': {
        'id': mockUserId,
        'name': name,
        'phone': phone,
        'email': email ?? '',
        'role': role,
        'created_at': DateTime.now().toIso8601String(),
      },
      'message': 'User registered successfully (mock)',
    };
    
    // Save token and user data (same logic as real API)
    await StorageService.saveToken(mockToken);
    await StorageService.saveUserData(
      userId: mockUserId,
      role: role,
      phone: phone,
      name: name,
      email: email,
    );
    
    return mockResponse;
  }

  /// POST /api/auth/login
  Future<Map<String, dynamic>> login({
    String? phone,
    String? email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
          'password': password,
        },
      );
      
      // Save token and user data
      if (response.data['token'] != null) {
        await StorageService.saveToken(response.data['token']);
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
      }
      
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// GET /api/auth/profile
  Future<UserModel> getProfile() async {
    try {
      final response = await _dio.get('/auth/profile');
      return UserModel.fromJson(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// PATCH /api/auth/profile
  Future<UserModel> updateProfile({String? name, String? phone}) async {
    try {
      final response = await _dio.patch(
        '/auth/profile',
        data: {
          if (name != null) 'name': name,
          if (phone != null) 'phone': phone,
        },
      );
      return UserModel.fromJson(response.data['data']);
    } catch (e) {
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
  Future<Map<String, dynamic>> getAllProducts({
    String? category,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // Build full URL for logging
      final queryParams = <String, dynamic>{
        if (category != null) 'category': category,
        if (search != null && search.isNotEmpty) 'search': search,
        'page': page.toString(),
        'limit': limit.toString(),
      };
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      final fullUrl = '${_dio.options.baseUrl}/products${queryString.isNotEmpty ? '?$queryString' : ''}';
      
      print('📦 Frontend: Calling GET /api/products');
      print('   Full URL: $fullUrl');
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
      
      print('✅ Frontend: API response received');
      print('   Status code: ${response.statusCode}');
      print('   Response headers: ${response.headers.map}');
      print('   Response data type: ${response.data.runtimeType}');
      print('   Response data keys: ${response.data is Map ? (response.data as Map).keys.toList() : 'N/A'}');
      print('   Full response body: ${response.data}');
      print('   Has data field: ${response.data is Map && (response.data as Map).containsKey('data')}');
      print('   Has pagination field: ${response.data is Map && (response.data as Map).containsKey('pagination')}');
      
      if (response.data['data'] == null) {
        print('❌ Frontend: Response data field is null!');
        print('   Full response: ${response.data}');
        throw Exception('Invalid API response: missing data field');
      }
      
      final dataList = response.data['data'] as List?;
      if (dataList == null) {
        print('❌ Frontend: Response data is not a list!');
        print('   Data type: ${response.data['data'].runtimeType}');
        print('   Full response: ${response.data}');
        throw Exception('Invalid API response: data is not a list');
      }
      
      print('   Products count: ${dataList.length}');
      
      final products = <ProductModel>[];
      for (int i = 0; i < dataList.length; i++) {
        try {
          final product = ProductModel.fromJson(dataList[i] as Map<String, dynamic>);
          products.add(product);
        } catch (parseError) {
          print('❌ Frontend: Failed to parse product at index $i');
          print('   Parse error: $parseError');
          print('   Product data: ${dataList[i]}');
          // Continue with other products instead of failing completely
        }
      }
      
      print('✅ Frontend: Successfully parsed ${products.length}/${dataList.length} products');
      
      return {
        'products': products,
        'pagination': response.data['pagination'],
      };
    } catch (e) {
      print('❌ Frontend: Error in getAllProducts');
      print('   Error type: ${e.runtimeType}');
      print('   Error message: $e');
      if (e is DioException) {
        print('   DioException type: ${e.type}');
        print('   Status code: ${e.response?.statusCode}');
        print('   Response data: ${e.response?.data}');
        print('   Request path: ${e.requestOptions.path}');
        print('   Request baseUrl: ${e.requestOptions.baseUrl}');
      }
      throw _handleError(e);
    }
  }

  /// GET /api/products/:id
  Future<ProductModel> getProductById(int id) async {
    try {
      final response = await _dio.get('/products/$id');
      return ProductModel.fromJson(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// GET /api/products/mine
  Future<List<ProductModel>> getMyProducts({String? status}) async {
    try {
      final response = await _dio.get(
        '/products/mine',
        queryParameters: {
          if (status != null) 'status': status,
        },
      );
      return (response.data['data'] as List)
          .map((json) => ProductModel.fromJson(json))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// POST /api/products/create
  Future<ProductModel> createProduct({
    required String title,
    String? description,
    String? imageUrl,
    required double startingPrice,
    int? duration,
    int? categoryId,
  }) async {
    try {
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
      return ProductModel.fromJson(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // ==================== BIDS ====================

  /// POST /api/bids/place
  Future<BidModel> placeBid({
    required int productId,
    required double amount,
  }) async {
    try {
      final response = await _dio.post(
        '/bids/place',
        data: {
          'productId': productId,
          'amount': amount,
        },
      );
      return BidModel.fromJson(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// GET /api/bids/:productId
  Future<List<BidModel>> getBidsByProduct(int productId) async {
    try {
      final response = await _dio.get('/bids/$productId');
      return (response.data['data'] as List)
          .map((json) => BidModel.fromJson(json))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// GET /api/bids/mine
  Future<List<BidModel>> getMyBids() async {
    try {
      final response = await _dio.get('/bids/mine');
      return (response.data['data'] as List)
          .map((json) => BidModel.fromJson(json))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  // ==================== NOTIFICATIONS ====================

  /// GET /api/notifications
  Future<List<NotificationModel>> getNotifications({
    bool? read,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get(
        '/notifications',
        queryParameters: {
          if (read != null) 'read': read.toString(),
          'limit': limit,
        },
      );
      return (response.data['data'] as List)
          .map((json) => NotificationModel.fromJson(json))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// PATCH /api/notifications/read/:id
  Future<NotificationModel> markNotificationAsRead(int id) async {
    try {
      final response = await _dio.patch('/notifications/read/$id');
      return NotificationModel.fromJson(response.data['data']);
    } catch (e) {
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


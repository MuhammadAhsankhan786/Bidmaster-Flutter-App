import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserRole = 'user_role';
  static const String _keyUserPhone = 'user_phone';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';

  static Future<SharedPreferences> get _prefs async {
    return await SharedPreferences.getInstance();
  }

  // Token management
  static Future<void> saveToken(String token) async {
    final prefs = await _prefs;
    await prefs.setString(_keyToken, token);
  }

  static Future<String?> getToken() async {
    final prefs = await _prefs;
    return prefs.getString(_keyToken);
  }

  static Future<void> clearToken() async {
    final prefs = await _prefs;
    await prefs.remove(_keyToken);
  }

  // User data management
  static Future<void> saveUserData({
    required int userId,
    required String role,
    required String phone,
    String? name,
    String? email,
  }) async {
    final prefs = await _prefs;
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyUserRole, role);
    await prefs.setString(_keyUserPhone, phone);
    if (name != null) {
      await prefs.setString(_keyUserName, name);
    }
    if (email != null) {
      await prefs.setString(_keyUserEmail, email);
    }
  }

  static Future<int?> getUserId() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyUserId);
  }

  static Future<String?> getUserRole() async {
    final prefs = await _prefs;
    return prefs.getString(_keyUserRole);
  }

  static Future<String?> getUserPhone() async {
    final prefs = await _prefs;
    return prefs.getString(_keyUserPhone);
  }

  static Future<String?> getUserName() async {
    final prefs = await _prefs;
    return prefs.getString(_keyUserName);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await _prefs;
    return prefs.getString(_keyUserEmail);
  }

  // Clear all user data
  static Future<void> clearAll() async {
    final prefs = await _prefs;
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyUserPhone);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}


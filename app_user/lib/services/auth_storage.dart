import 'package:shared_preferences/shared_preferences.dart';

/// Persistiert das JWT lokal (SharedPreferences — funktioniert auch im Web
/// via localStorage).
class AuthStorage {
  static const _tokenKey = 'auth_token';

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}

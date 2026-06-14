import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistiert Token + Anzeige-/Branding-Infos der aktuellen Sitzung lokal
/// (SharedPreferences — funktioniert auch im Web via localStorage).
///
/// Es gibt (bewusst, Grundgerüst) keinen `/api/customer-auth/me`-Endpunkt —
/// die beim Login/Invite-Accept erhaltenen Anzeigedaten (Kunden-/Mandanten-
/// name, Branding-Farbe) werden deshalb zusammen mit dem Token gespeichert
/// und beim App-Start direkt wiederverwendet.
class AuthStorage {
  static const _tokenKey = 'customer_auth_token';
  static const _sessionKey = 'customer_auth_session';

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<Map<String, dynamic>?> readSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveSession({required String token, required Map<String, dynamic> session}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_sessionKey, jsonEncode(session));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_sessionKey);
  }
}

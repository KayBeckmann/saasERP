import 'package:flutter/foundation.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';
import '../services/auth_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Hält den Login-Zustand der User-App: JWT, aktueller Benutzer + Mandant.
class AuthController extends ChangeNotifier {
  AuthController({ApiClient? apiClient, AuthStorage? authStorage})
      : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage();

  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  AuthStatus status = AuthStatus.unknown;
  String? token;
  AppUser? user;
  Tenant? tenant;
  List<TenantAccess> availableTenants = [];
  String? errorMessage;
  bool isLoading = false;

  /// Beim App-Start: gespeichertes Token prüfen und Profil laden.
  Future<void> restoreSession() async {
    final storedToken = await _authStorage.readToken();
    if (storedToken == null) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // Ablauf lokal prüfen, bevor ein Backend-Request gemacht wird.
    if (TokenCodec.decodeUnverified(storedToken).isExpired) {
      await _authStorage.clearToken();
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      final me = await _apiClient.me(storedToken);
      token = storedToken;
      user = me.user;
      tenant = me.tenant;
      status = AuthStatus.authenticated;
      await _loadAvailableTenants();
    } on ApiException {
      await _authStorage.clearToken();
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> register({
    required String companyName,
    required String email,
    required String password,
  }) =>
      _runAuthAction(
        () => _apiClient.register(
          companyName: companyName,
          email: email,
          password: password,
        ),
      );

  Future<bool> login({required String email, required String password}) =>
      _runAuthAction(
        () => _apiClient.login(email: email, password: password),
      );

  Future<bool> _runAuthAction(Future<AuthResponse> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await action();
      await _authStorage.saveToken(response.token);
      token = response.token;
      user = response.user;
      tenant = response.tenant;
      status = AuthStatus.authenticated;
      await _loadAvailableTenants();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Wechselt den aktiven Mandanten (Tenant-Auswahl für Nutzer mit
  /// mehreren Zugängen, z. B. Berater) und stellt ein neu skopiertes
  /// JWT für den Ziel-Mandanten aus.
  Future<bool> switchTenant(String tenantId) async {
    final currentToken = token;
    if (currentToken == null) return false;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.switchTenant(
        token: currentToken,
        tenantId: tenantId,
      );
      await _authStorage.saveToken(response.token);
      token = response.token;
      user = response.user;
      tenant = response.tenant;
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Setzt die Branding-Farbe des aktuellen Mandanten (nur Owner).
  /// `brandingColor: null` setzt auf das generische Theme zurück.
  Future<bool> updateTenantBranding(String? brandingColor) async {
    final currentToken = token;
    if (currentToken == null) return false;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      tenant = await _apiClient.updateTenantBranding(
        token: currentToken,
        brandingColor: brandingColor,
      );
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAvailableTenants() async {
    if (token == null) return;
    try {
      availableTenants = await _apiClient.meTenants(token!);
    } on ApiException {
      availableTenants = [];
    }
  }

  Future<void> logout() async {
    await _authStorage.clearToken();
    token = null;
    user = null;
    tenant = null;
    availableTenants = [];
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}

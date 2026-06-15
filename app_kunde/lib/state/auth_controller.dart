import 'package:flutter/foundation.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';
import '../services/auth_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Hält den Login-Zustand der Kunden-App: JWT, Zugang sowie Anzeige-/
/// Branding-Infos des einladenden Mandanten.
class AuthController extends ChangeNotifier {
  AuthController({ApiClient? apiClient, AuthStorage? authStorage})
      : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage();

  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  ApiClient get apiClient => _apiClient;

  AuthStatus status = AuthStatus.unknown;
  String? token;
  CustomerPortalAccount? account;
  String? customerName;
  String? tenantName;
  String? tenantBrandingColor;
  String? tenantLogoUrl;
  String? errorMessage;
  bool isLoading = false;

  /// Beim App-Start: gespeicherte Sitzung prüfen.
  Future<void> restoreSession() async {
    final storedToken = await _authStorage.readToken();
    final session = await _authStorage.readSession();
    if (storedToken == null || session == null) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // Ablauf lokal prüfen, bevor die Sitzung wiederhergestellt wird.
    if (TokenCodec.decodeUnverified(storedToken).isExpired) {
      await _authStorage.clear();
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    _applyResponse(CustomerAuthResponse.fromJson(session), token: storedToken);
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) =>
      _runAuthAction(() => _apiClient.login(email: email, password: password));

  Future<bool> acceptInvite({required String inviteToken, required String password}) => _runAuthAction(
        () => _apiClient.acceptInvite(inviteToken: inviteToken, password: password),
      );

  Future<bool> _runAuthAction(Future<CustomerAuthResponse> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await action();
      await _authStorage.saveSession(token: response.token, session: response.toJson());
      _applyResponse(response, token: response.token);
      status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _applyResponse(CustomerAuthResponse response, {required String token}) {
    this.token = token;
    account = response.account;
    customerName = response.customerName;
    tenantName = response.tenantName;
    tenantBrandingColor = response.tenantBrandingColor;
    tenantLogoUrl = response.tenantLogoUrl;
  }

  Future<void> logout() async {
    await _authStorage.clear();
    token = null;
    account = null;
    customerName = null;
    tenantName = null;
    tenantBrandingColor = null;
    tenantLogoUrl = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}

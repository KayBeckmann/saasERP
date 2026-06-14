import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/dashboard_screen.dart';
import 'screens/invite_accept_screen.dart';
import 'screens/login_screen.dart';
import 'state/auth_controller.dart';
import 'theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthController()..restoreSession(),
      child: Consumer<AuthController>(
        builder: (context, auth, _) => MaterialApp(
          title: 'Kundenportal',
          theme: buildAppTheme(primaryColor: parseBrandingColor(auth.tenantBrandingColor)),
          home: const RootScreen(),
        ),
      ),
    );
  }
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    final inviteToken = _inviteTokenFromUrl();
    if (inviteToken != null && auth.status != AuthStatus.authenticated) {
      return InviteAcceptScreen(inviteToken: inviteToken);
    }

    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.authenticated:
        return const DashboardScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}

/// Liest `<token>` aus einer URL der Form `/invite/<token>` (Deep-Link aus
/// dem Einladungslink). `null`, falls die App nicht über einen solchen Pfad
/// aufgerufen wurde.
String? _inviteTokenFromUrl() {
  final segments = Uri.base.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length == 2 && segments[0] == 'invite') {
    return segments[1];
  }
  return null;
}

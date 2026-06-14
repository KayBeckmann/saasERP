import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../theme.dart';
import 'login_screen.dart';

/// Aufgerufen über `/invite/<token>` — Endkunde sieht eine Vorschau seiner
/// Einladung (Mandant, Kunde, E-Mail) und vergibt sein Passwort.
class InviteAcceptScreen extends StatefulWidget {
  const InviteAcceptScreen({required this.inviteToken, super.key});

  final String inviteToken;

  @override
  State<InviteAcceptScreen> createState() => _InviteAcceptScreenState();
}

class _InviteAcceptScreenState extends State<InviteAcceptScreen> {
  late Future<CustomerInvitePreview> _previewFuture;
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<AuthController>().apiClient;
    _previewFuture = apiClient.getInvitePreview(widget.inviteToken);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthController auth) async {
    if (!_formKey.currentState!.validate()) return;
    await auth.acceptInvite(inviteToken: widget.inviteToken, password: _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CustomerInvitePreview>(
      future: _previewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        snapshot.error is ApiException && (snapshot.error! as ApiException).statusCode == 404
                            ? 'Dieser Einladungslink ist ungültig oder wurde bereits verwendet.'
                            : 'Einladung konnte nicht geladen werden: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                        ),
                        child: const Text('Zur Anmeldung'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final preview = snapshot.data!;
        final auth = context.watch<AuthController>();

        return Theme(
          data: buildAppTheme(primaryColor: parseBrandingColor(preview.tenantBrandingColor)),
          child: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Willkommen bei ${preview.tenantName}',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sie wurden als ${preview.customerName} (${preview.email}) eingeladen. '
                          'Vergeben Sie ein Passwort für Ihr Kundenportal-Konto.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(labelText: 'Passwort'),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.length < 8) {
                              return 'Mindestens 8 Zeichen';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmController,
                          decoration: const InputDecoration(labelText: 'Passwort wiederholen'),
                          obscureText: true,
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return 'Passwörter stimmen nicht überein';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _submit(auth),
                        ),
                        if (auth.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            auth.errorMessage!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: auth.isLoading ? null : () => _submit(auth),
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Passwort festlegen & loslegen'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

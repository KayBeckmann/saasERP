import 'package:flutter/material.dart';

/// Logo des Mandanten (Whitelabel-Branding). Zeigt nichts an, falls keine
/// `logoUrl` gesetzt ist oder das Bild nicht geladen werden kann.
class TenantLogo extends StatelessWidget {
  const TenantLogo({required this.logoUrl, this.height = 32, super.key});

  final String? logoUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();

    return Image.network(
      url,
      height: height,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

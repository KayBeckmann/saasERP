import 'package:flutter/material.dart';

import '../theme.dart';

/// Farbton einer [StatusChip] — Screens bilden ihre fachlichen Status
/// (z. B. `InvoiceStatus.overdue`) auf einen dieser Töne ab.
enum StatusTone { neutral, info, success, warning, error }

/// Pillenförmiger Status-Chip mit Low-Opacity-Hintergrundtinte, analog
/// `app_user/lib/widgets/status_chip.dart` — bewusst dupliziert, da beide
/// Apps eigene Designsysteme/Konstanten haben.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.tone = StatusTone.neutral});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Color _colorFor(StatusTone tone) {
    switch (tone) {
      case StatusTone.success:
        return const Color(0xFF1E7E34);
      case StatusTone.warning:
        return const Color(0xFFB07D00);
      case StatusTone.error:
        return const Color(0xFFC62828);
      case StatusTone.info:
        return slateSecondary;
      case StatusTone.neutral:
        return const Color(0xFF5F5F5F);
    }
  }
}

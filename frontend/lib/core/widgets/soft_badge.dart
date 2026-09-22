import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Soft status / permission / hold pill — matches HTML `.badge`.
class SoftBadge extends StatelessWidget {
  const SoftBadge({
    super.key,
    required this.label,
    this.tone = SoftBadgeTone.positive,
  });

  const SoftBadge.permission({super.key, required bool allowed})
    : label = allowed ? 'مسموح' : 'غير مسموح',
      tone = allowed ? SoftBadgeTone.positive : SoftBadgeTone.negative;

  const SoftBadge.status({super.key, required bool active})
    : label = active ? 'نشط' : 'موقوف',
      tone = active ? SoftBadgeTone.positive : SoftBadgeTone.negative;

  const SoftBadge.hold({super.key, this.label = 'Hold'})
    : tone = SoftBadgeTone.hold;

  const SoftBadge.pending({super.key})
    : label = 'معلّق',
      tone = SoftBadgeTone.hold;

  const SoftBadge.done({super.key})
    : label = 'تم التنفيذ',
      tone = SoftBadgeTone.positive;

  const SoftBadge.immediate({super.key})
    : label = 'فوري',
      tone = SoftBadgeTone.info;

  final String label;
  final SoftBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      SoftBadgeTone.positive => (
        bg: HesbaColors.tealLight,
        fg: HesbaColors.tealSoft,
      ),
      SoftBadgeTone.negative => (
        bg: HesbaColors.redLight,
        fg: HesbaColors.redSoft,
      ),
      SoftBadgeTone.hold => (
        bg: HesbaColors.warningLight,
        fg: HesbaColors.warning,
      ),
      SoftBadgeTone.info => (
        bg: const Color(0xFFE9EEF6),
        fg: const Color(0xFF50657D),
      ),
    };

    return Container(
      constraints: const BoxConstraints(minWidth: 76),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: HesbaText.badge.copyWith(color: colors.fg),
      ),
    );
  }
}

enum SoftBadgeTone { positive, negative, hold, info }

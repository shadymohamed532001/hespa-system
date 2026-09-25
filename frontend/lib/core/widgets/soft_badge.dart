import 'package:flutter/material.dart';

import '../settings/hesba_l10n.dart';
import '../theme/app_theme.dart';
import '../settings/tr.dart';

enum _SoftBadgeKind {
  custom,
  permission,
  status,
  hold,
  pending,
  done,
  immediate,
}

/// Soft status / permission / hold pill — matches HTML `.badge`.
class SoftBadge extends StatelessWidget {
  const SoftBadge({
    super.key,
    required this.label,
    this.tone = SoftBadgeTone.positive,
  }) : _kind = _SoftBadgeKind.custom,
       _flag = null;

  const SoftBadge.permission({super.key, required bool allowed})
    : label = '',
      tone = allowed ? SoftBadgeTone.positive : SoftBadgeTone.negative,
      _kind = _SoftBadgeKind.permission,
      _flag = allowed;

  const SoftBadge.status({super.key, required bool active})
    : label = '',
      tone = active ? SoftBadgeTone.positive : SoftBadgeTone.negative,
      _kind = _SoftBadgeKind.status,
      _flag = active;

  const SoftBadge.hold({super.key, this.label = 'Hold'})
    : tone = SoftBadgeTone.hold,
      _kind = _SoftBadgeKind.hold,
      _flag = null;

  const SoftBadge.pending({super.key})
    : label = '',
      tone = SoftBadgeTone.hold,
      _kind = _SoftBadgeKind.pending,
      _flag = null;

  const SoftBadge.done({super.key})
    : label = '',
      tone = SoftBadgeTone.positive,
      _kind = _SoftBadgeKind.done,
      _flag = null;

  const SoftBadge.immediate({super.key})
    : label = '',
      tone = SoftBadgeTone.info,
      _kind = _SoftBadgeKind.immediate,
      _flag = null;

  final String label;
  final SoftBadgeTone tone;
  final _SoftBadgeKind _kind;
  final bool? _flag;

  String _resolvedLabel(BuildContext context) {
    final english = HesbaL10n.maybeOf(context)?.strings.isArabic == false;
    switch (_kind) {
      case _SoftBadgeKind.custom:
      case _SoftBadgeKind.hold:
        return label;
      case _SoftBadgeKind.permission:
        if (_flag == true) return english ? 'Allowed' : 'مسموح';
        return english ? 'Denied' : 'غير مسموح';
      case _SoftBadgeKind.status:
        if (_flag == true) {
          return english ? 'Active' : tr(ar: 'نشط', en: 'Active');
        }
        return english ? 'Inactive' : tr(ar: 'موقوف', en: 'Inactive');
      case _SoftBadgeKind.pending:
        return english ? 'Pending' : tr(ar: 'معلّق', en: 'Pending');
      case _SoftBadgeKind.done:
        return english ? 'Done' : 'تم التنفيذ';
      case _SoftBadgeKind.immediate:
        return english ? 'Immediate' : tr(ar: 'فوري', en: 'Fawry');
    }
  }

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
        _resolvedLabel(context),
        textAlign: TextAlign.center,
        style: HesbaText.badge.copyWith(color: colors.fg),
      ),
    );
  }
}

enum SoftBadgeTone { positive, negative, hold, info }

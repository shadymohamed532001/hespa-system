import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.note,
    this.accent = false,
    this.warning = false,
  });
  final String label;
  final String value;
  final String note;
  final bool accent;
  final bool warning;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: warning
          ? const Color(0xFFFFFDF8)
          : accent
          ? const Color(0xFFFBFEFD)
          : Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: warning
            ? const Color(0xFFF1DFB7)
            : accent
            ? const Color(0x400B8C7E)
            : HesbaColors.border,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: HesbaColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: HesbaColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: const TextStyle(color: HesbaColors.muted, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

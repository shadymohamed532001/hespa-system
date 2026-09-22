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
  Widget build(BuildContext context) => Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: warning
            ? const Color(0xFFF0D18E)
            : accent
            ? const Color(0xFFB8DED8)
            : HesbaColors.border,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(23),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: HesbaColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: HesbaColors.navy,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            note,
            style: const TextStyle(color: HesbaColors.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

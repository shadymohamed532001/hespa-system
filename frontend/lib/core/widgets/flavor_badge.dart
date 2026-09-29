import 'package:flutter/material.dart';

import '../settings/app_flavor.dart';
import '../theme/app_theme.dart';

class FlavorBadge extends StatelessWidget {
  const FlavorBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final production = isProductionFlavor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: production ? HesbaColors.redLight : HesbaColors.tealLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        production ? 'برودكشن' : 'تطوير',
        style: TextStyle(
          color: production ? HesbaColors.red : HesbaColors.tealDark,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: HesbaText.family,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared square icon button used in the top context bar.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.onPressed,
    required this.tooltip,
    this.icon,
    this.child,
  }) : assert(icon != null || child != null);

  final VoidCallback onPressed;
  final String tooltip;
  final IconData? icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF2A4050) : HesbaColors.border;
    final fg = isDark ? const Color(0xFFE6EEF2) : HesbaColors.navy;
    final bg = isDark ? const Color(0xFF152833) : Colors.white;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: BorderSide(color: border),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: child ?? Icon(icon, color: fg, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

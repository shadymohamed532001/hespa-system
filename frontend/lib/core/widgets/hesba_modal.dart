import 'package:flutter/material.dart';

import '../settings/hesba_l10n.dart';
import '../theme/app_theme.dart';

/// Shared white modal style matching «استلام كاش من مندوب».
Future<T?> showHesbaModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 590,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: const Color(0x990B2430),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(22),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.of(ctx).size.height - 44,
        ),
        child: builder(ctx),
      ),
    ),
  );
}

class HesbaModalCard extends StatelessWidget {
  const HesbaModalCard({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.footer,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x520A1F2A),
            blurRadius: 80,
            offset: Offset(0, 25),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(27),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: HesbaText.modalTitle),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: HesbaText.bodyMuted),
            ],
            const SizedBox(height: 20),
            child,
            if (actions != null) ...[const SizedBox(height: 24), actions!],
            if (footer != null) ...[const SizedBox(height: 14), footer!],
          ],
        ),
      ),
    );
  }
}

class HesbaModalField extends StatelessWidget {
  const HesbaModalField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: HesbaText.fieldLabel),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}

class HesbaModalCallout extends StatelessWidget {
  const HesbaModalCallout({
    super.key,
    required this.child,
    this.backgroundColor = const Color(0xFFEEF4F7),
    this.borderColor,
    this.textStyle = HesbaText.callout,
  });

  final Widget child;
  final Color backgroundColor;
  final Color? borderColor;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: borderColor == null ? null : Border.all(color: borderColor!),
        borderRadius: BorderRadius.circular(11),
      ),
      child: DefaultTextStyle(style: textStyle, child: child),
    );
  }
}

class HesbaModalActions extends StatelessWidget {
  const HesbaModalActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.onCancel,
    this.cancelLabel,
    this.primaryEnabled = true,
    this.cancelEnabled = true,
    this.danger = false,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onCancel;
  final String? cancelLabel;
  final bool primaryEnabled;
  final bool cancelEnabled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final resolvedCancel =
        cancelLabel ?? HesbaL10n.maybeOf(context)?.strings.cancel ?? 'Cancel';
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton(
          onPressed: primaryEnabled ? onPrimary : null,
          style: danger
              ? FilledButton.styleFrom(backgroundColor: HesbaColors.red)
              : null,
          child: Text(primaryLabel),
        ),
        OutlinedButton(
          onPressed: cancelEnabled
              ? (onCancel ?? () => Navigator.of(context).pop())
              : null,
          child: Text(resolvedCancel),
        ),
      ],
    );
  }
}

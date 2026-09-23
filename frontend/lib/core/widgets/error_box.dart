import 'package:flutter/material.dart';

import '../settings/hesba_l10n.dart';
import '../theme/app_theme.dart';

class ErrorBox extends StatelessWidget {
  const ErrorBox({super.key, required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) {
    final retryLabel = HesbaL10n.maybeOf(context)?.strings.retry ?? 'Retry';
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 44,
                color: HesbaColors.muted,
              ),
              const SizedBox(height: 14),
              Text(message),
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: retry, child: Text(retryLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

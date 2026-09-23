import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Full-screen gate when Remote Config `IS_SYSTEM_WORK` is false.
class SystemUnavailablePage extends StatelessWidget {
  const SystemUnavailablePage({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFE9F0F3),
                Color(0xFFF7F9FA),
                Color(0xFFE6EFEF),
              ],
              stops: [0, 0.55, 1],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(36, 40, 36, 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: HesbaColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x29102F3E),
                          blurRadius: 80,
                          offset: Offset(0, 28),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: HesbaColors.redLight,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.handyman_outlined,
                            size: 36,
                            color: HesbaColors.red,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'حِسبة',
                          style: HesbaText.loginTitle.copyWith(
                            color: HesbaColors.navy,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'النظام غير متاح حالياً',
                          textAlign: TextAlign.center,
                          style: HesbaText.sectionTitle.copyWith(
                            color: HesbaColors.ink,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'يرجى التواصل مع مطور السيستم لحل مشكلة',
                          textAlign: TextAlign.center,
                          style: HesbaText.body.copyWith(
                            fontSize: 15,
                            color: HesbaColors.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'تم إيقاف التشغيل مؤقتاً من لوحة التحكم. '
                          'بعد حل المشكلة وإعادة تفعيل النظام يمكنك المحاولة مرة أخرى.',
                          textAlign: TextAlign.center,
                          style: HesbaText.bodyMuted,
                        ),
                        if (onRetry != null) ...[
                          const SizedBox(height: 24),
                          FilledButton.tonal(
                            onPressed: onRetry,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

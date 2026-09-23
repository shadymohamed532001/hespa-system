import 'package:flutter/widgets.dart';

import 'app_settings.dart';
import 'app_strings.dart';

/// Provides locale-aware UI copy + helpers under the MaterialApp tree.
class HesbaL10n extends InheritedWidget {
  const HesbaL10n({
    super.key,
    required this.settings,
    required super.child,
  });

  final AppSettings settings;

  AppStrings get strings => AppStrings.of(settings.locale);
  bool get isArabic => settings.isArabic;

  String t({required String ar, required String en}) => isArabic ? ar : en;

  static HesbaL10n of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HesbaL10n>();
    assert(scope != null, 'HesbaL10n not found in widget tree');
    return scope!;
  }

  static HesbaL10n? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HesbaL10n>();
  }

  @override
  bool updateShouldNotify(HesbaL10n oldWidget) {
    return oldWidget.settings.locale != settings.locale ||
        oldWidget.settings.themeMode != settings.themeMode;
  }
}

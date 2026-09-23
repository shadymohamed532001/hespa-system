import 'package:flutter/widgets.dart';

import '../network/api_client.dart';
import 'hesba_l10n.dart';

extension HesbaContextL10n on BuildContext {
  HesbaL10n get l10n => HesbaL10n.of(this);

  String t({required String ar, required String en}) =>
      HesbaL10n.of(this).t(ar: ar, en: en);

  String apiError(Object error) {
    final locale = HesbaL10n.maybeOf(this)?.strings.localeCode;
    return ApiClient.errorMessage(error, locale: locale);
  }
}

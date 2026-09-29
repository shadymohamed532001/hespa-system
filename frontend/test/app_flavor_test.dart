import 'package:flutter_test/flutter_test.dart';
import 'package:hesba_desktop/core/settings/app_flavor.dart';

void main() {
  test('the selected macOS environment uses its matching API', () {
    const selected = String.fromEnvironment('HESBA_APP_FLAVOR');
    final expected = selected == 'prod' ? AppFlavor.prod : AppFlavor.dev;

    expect(appEnvironment, expected);
    expect(
      flavorApiBaseUrl,
      expected == AppFlavor.prod ? productionApiBaseUrl : developmentApiBaseUrl,
    );
  });
}

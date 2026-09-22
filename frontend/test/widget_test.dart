import 'package:flutter_test/flutter_test.dart';
import 'package:hesba_desktop/src/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the Hesba login page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const HesbaApp());
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('دخول إلى حِسبة'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hesba_desktop/app/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the Hesba login page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const HesbaApp());
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('دخول إلى النظام'), findsOneWidget);
  });

  testWidgets('reveals admin recovery after five bottom-left taps', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const HesbaApp());
    await tester.pumpAndSettle();

    const recoveryIcon = Icons.admin_panel_settings_outlined;
    expect(find.byIcon(recoveryIcon), findsNothing);
    final bottomLeft = tester.getBottomLeft(find.byType(Scaffold).first);
    for (var tap = 0; tap < 5; tap++) {
      await tester.tapAt(bottomLeft + const Offset(20, -20));
    }
    await tester.pump();

    expect(find.byIcon(recoveryIcon), findsOneWidget);
    await tester.tap(find.byIcon(recoveryIcon));
    await tester.pumpAndSettle();
    expect(find.text('إنشاء مدير استعادة'), findsOneWidget);
  });
}

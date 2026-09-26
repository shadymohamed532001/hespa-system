import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesba_desktop/app/app.dart';
import 'package:hesba_desktop/core/network/api_client.dart';
import 'package:hesba_desktop/core/settings/app_settings.dart';
import 'package:hesba_desktop/features/auth/session_controller.dart';

HesbaApp buildTestApp() {
  final session = SessionController(ApiClient())..ready = true;
  final settings = AppSettings()..ready = true;
  return HesbaApp(
    checkSystemAvailability: false,
    sessionController: session,
    appSettings: settings,
  );
}

void main() {
  testWidgets('opens the admin login form from the portal chooser', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('مدخل الأدمن'), findsOneWidget);
    expect(find.text('مدخل الموظفين'), findsOneWidget);

    await tester.tap(find.text('مدخل الأدمن'));
    await tester.pumpAndSettle();

    expect(find.text('اسم المستخدم'), findsOneWidget);
    expect(find.text('كلمة المرور'), findsOneWidget);
    expect(find.text('دخول مدخل الأدمن'), findsOneWidget);
  });

  testWidgets('reveals admin recovery after five bottom-left taps', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('مدخل الأدمن'));
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

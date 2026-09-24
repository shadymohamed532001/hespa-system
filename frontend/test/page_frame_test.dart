import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesba_desktop/core/widgets/page_frame.dart';

void main() {
  Widget testApp() {
    return MaterialApp(
      home: Scaffold(
        body: PageFrame(
          title: 'المحافظ الإلكترونية وInstaPay',
          subtitle: 'وصف الصفحة الذي يجب أن يظل واضحًا على كل المقاسات',
          actions: [
            for (var index = 1; index <= 4; index++)
              FilledButton(onPressed: () {}, child: Text('إجراء رقم $index')),
          ],
          child: const SizedBox(height: 200, child: Text('محتوى الصفحة')),
        ),
      ),
    );
  }

  Future<void> setViewport(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
  }

  testWidgets('stacks page actions below the title on mobile', (tester) async {
    await setViewport(tester, const Size(440, 900));

    expect(tester.takeException(), isNull);
    expect(find.text('محتوى الصفحة'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('إجراء رقم 1')).dy,
      greaterThan(
        tester
            .getBottomLeft(
              find.text('وصف الصفحة الذي يجب أن يظل واضحًا على كل المقاسات'),
            )
            .dy,
      ),
    );
  });

  testWidgets('keeps page header and actions visible on desktop', (
    tester,
  ) async {
    await setViewport(tester, const Size(1440, 900));

    expect(tester.takeException(), isNull);
    expect(find.text('المحافظ الإلكترونية وInstaPay'), findsOneWidget);
    expect(find.byType(FilledButton), findsNWidgets(4));
    expect(find.text('محتوى الصفحة'), findsOneWidget);
  });
}

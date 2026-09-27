import 'package:flutter_test/flutter_test.dart';
import 'package:hesba_desktop/features/accounts/fawry_cash_input.dart';

void main() {
  test('calculates a Fawry deposit total from banknote counts', () {
    expect(
      fawryCashTotal({
        'count200': 10,
        'count100': 5,
        'count50': 2,
        'count20': 3,
        'count10': 4,
        'count5': 6,
      }),
      2730,
    );
  });
}

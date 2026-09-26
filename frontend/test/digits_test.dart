import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesba_desktop/core/utils/digits.dart';

void main() {
  test('Arabic and Persian digits parse as western numbers', () {
    expect(normalizeDigits('٥٠٬٠٠٠٫٥'), '50000.5');
    expect(normalizeDigits('۴۰۰۰۰'), '40000');
    expect(normalizeDigits('100'), '100');
    expect(parseNum('١٠'), 10);
    expect(parseInt('٢٥'), 25);
  });

  test('the amount field keeps the cursor when an Arabic digit is typed', () {
    const formatter = ArabicDigitsFormatter();
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: '١',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    expect(result.text, '1');
    expect(result.selection.extentOffset, 1);
  });
}

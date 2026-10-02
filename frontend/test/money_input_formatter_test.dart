import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesba_desktop/core/utils/digits.dart';

void main() {
  const formatter = MoneyInputFormatter();
  TextEditingValue value(String text, [int? cursor]) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor ?? text.length),
  );
  test('groups typed and pasted amounts and preserves their numeric value', () {
    for (final input in ['1000000', '١٠٠٠٠٠٠', '۱۰۰۰۰۰۰', '1,000,000']) {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        value(input),
      );
      expect(result.text, '1,000,000');
      expect(result.selection.extentOffset, 9);
      expect(parseNum(result.text), 1000000);
    }
  });
  test('keeps decimal input including unfinished decimals', () {
    for (final input in ['1000.', '1000.50']) {
      expect(
        formatter.formatEditUpdate(TextEditingValue.empty, value(input)).text,
        input == '1000.' ? '1,000.' : '1,000.50',
      );
    }
    expect(
      formatter.formatEditUpdate(TextEditingValue.empty, value('١٬٠٠٠٫٥')).text,
      '1,000.5',
    );
  });
  test('keeps the caret while inserting in the middle', () {
    final result = formatter.formatEditUpdate(
      value('1,000', 3),
      value('1,0200', 4),
    );
    expect(result.text, '10,200');
    expect(result.selection.extentOffset, 4);
  });
  test('backspace at a separator removes the preceding digit', () {
    final result = formatter.formatEditUpdate(
      value('12,345', 3),
      value('12345', 2),
    );
    expect(result.text, '1,345');
    expect(result.selection.extentOffset, 1);
  });
  test('supports clearing and rejects invalid monetary text', () {
    expect(formatter.formatEditUpdate(value('1,000'), value('')).text, '');
    expect(
      formatter.formatEditUpdate(value('1,000'), value('1000x')).text,
      '1,000',
    );
  });
}

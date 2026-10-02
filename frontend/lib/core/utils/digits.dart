import 'package:flutter/services.dart';

/// Arabic-Indic (٠١٢) and Persian (۰۱۲) digits become Western digits (012).
String normalizeDigits(String input) {
  final buffer = StringBuffer();
  for (var index = 0; index < input.length; index++) {
    final code = input.codeUnitAt(index);
    if (code >= 0x0660 && code <= 0x0669) {
      buffer.writeCharCode(0x30 + code - 0x0660);
    } else if (code >= 0x06F0 && code <= 0x06F9) {
      buffer.writeCharCode(0x30 + code - 0x06F0);
    } else if (code == 0x066B) {
      buffer.write('.');
    } else if (code == 0x066C) {
      // Arabic thousands separator.
    } else {
      buffer.writeCharCode(code);
    }
  }
  return buffer.toString();
}

num? parseNum(String? raw) {
  if (raw == null) return null;
  final text = normalizeDigits(
    raw,
  ).trim().replaceAll(',', '').replaceAll(' ', '');
  if (text.isEmpty) return null;
  return num.tryParse(text);
}

int? parseInt(String? raw) {
  if (raw == null) return null;
  final text = normalizeDigits(
    raw,
  ).trim().replaceAll(',', '').replaceAll(' ', '');
  if (text.isEmpty) return null;
  return int.tryParse(text);
}

/// Lets a numeric field accept an Arabic or English keyboard.
class ArabicDigitsFormatter extends TextInputFormatter {
  const ArabicDigitsFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final mapping = <int>[0];
    final buffer = StringBuffer();
    for (var index = 0; index < newValue.text.length; index++) {
      final code = newValue.text.codeUnitAt(index);
      if (code >= 0x0660 && code <= 0x0669) {
        buffer.writeCharCode(0x30 + code - 0x0660);
      } else if (code >= 0x06F0 && code <= 0x06F9) {
        buffer.writeCharCode(0x30 + code - 0x06F0);
      } else if (code == 0x066B) {
        buffer.write('.');
      } else if (code == 0x066C) {
        mapping.add(buffer.length);
        continue;
      } else {
        buffer.writeCharCode(code);
      }
      mapping.add(buffer.length);
    }
    final text = buffer.toString();
    if (text == newValue.text) return newValue;
    int mapOffset(int offset) {
      if (offset <= 0) return 0;
      if (offset >= mapping.length) return text.length;
      return mapping[offset];
    }

    final selection = newValue.selection;
    return TextEditingValue(
      text: text,
      selection: selection.isValid
          ? TextSelection(
              baseOffset: mapOffset(selection.baseOffset),
              extentOffset: mapOffset(selection.extentOffset),
            )
          : TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Groups monetary input while preserving decimals and the editing selection.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    var input = newValue.text;
    var selection = newValue.selection;
    // Backspacing over a separator should remove the preceding digit.
    if (oldValue.selection.isCollapsed &&
        selection.isCollapsed &&
        oldValue.text.length == input.length + 1 &&
        selection.extentOffset == oldValue.selection.extentOffset - 1 &&
        selection.extentOffset > 0 &&
        oldValue.text[selection.extentOffset] == ',') {
      final offset = selection.extentOffset;
      input = input.replaceRange(offset - 1, offset, '');
      selection = TextSelection.collapsed(offset: offset - 1);
    }
    String clean(String value) =>
        normalizeDigits(value).replaceAll(',', '').replaceAll(' ', '');
    final raw = clean(input);
    if (!RegExp(r'^\d*(\.\d*)?$').hasMatch(raw)) return oldValue;
    final decimal = raw.indexOf('.');
    final integerLength = decimal < 0 ? raw.length : decimal;
    final buffer = StringBuffer();
    final offsets = <int>[0];
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && i < integerLength && (integerLength - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(raw[i]);
      offsets.add(buffer.length);
    }
    final text = buffer.toString();
    int mapOffset(int offset) {
      final count = clean(
        input.substring(0, offset.clamp(0, input.length)),
      ).length;
      return offsets[count];
    }

    return TextEditingValue(
      text: text,
      selection: selection.isValid
          ? TextSelection(
              baseOffset: mapOffset(selection.baseOffset),
              extentOffset: mapOffset(selection.extentOffset),
              affinity: selection.affinity,
              isDirectional: selection.isDirectional,
            )
          : TextSelection.collapsed(offset: text.length),
    );
  }
}

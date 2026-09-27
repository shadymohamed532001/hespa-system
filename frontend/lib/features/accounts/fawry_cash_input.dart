import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/digits.dart';
import '../../core/utils/money_formatter.dart';

const fawryDenominations = <int>[200, 100, 50, 20, 10, 5];

Map<String, int> emptyFawryCashCounts() => {
  for (final value in fawryDenominations) 'count$value': 0,
};

num fawryCashTotal(Map<String, int> counts) => fawryDenominations.fold<num>(
  0,
  (total, value) => total + value * (counts['count$value'] ?? 0),
);

class FawryCashInput extends StatefulWidget {
  const FawryCashInput({
    super.key,
    required this.onChanged,
    this.enabled = true,
  });

  final ValueChanged<Map<String, int>> onChanged;
  final bool enabled;

  @override
  State<FawryCashInput> createState() => _FawryCashInputState();
}

class _FawryCashInputState extends State<FawryCashInput> {
  final _controllers = {
    for (final value in fawryDenominations) value: TextEditingController(),
  };

  Map<String, int> get _counts => {
    for (final value in fawryDenominations)
      'count$value': parseInt(_controllers[value]!.text) ?? 0,
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _notify() {
    widget.onChanged(_counts);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final total = fawryCashTotal(_counts);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('عدد الأوراق النقدية', style: HesbaText.fieldLabel),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 480 ? 3 : 2;
            final spacing = 10.0;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: 10,
              children: [
                for (final value in fawryDenominations)
                  SizedBox(
                    width: width,
                    child: TextField(
                      controller: _controllers[value],
                      enabled: widget.enabled,
                      keyboardType: TextInputType.number,
                      textInputAction: value == 5
                          ? TextInputAction.done
                          : TextInputAction.next,
                      inputFormatters: [
                        const ArabicDigitsFormatter(),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (_) => _notify(),
                      decoration: InputDecoration(
                        labelText: 'فئة $value',
                        hintText: '0',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFE9F5EE),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xFFC9E5D3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'إجمالي الإيداع',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                money(total),
                style: const TextStyle(
                  color: Color(0xFF167443),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

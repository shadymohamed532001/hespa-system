import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/hesba_modal.dart';

/// "عليه X" when the agent owes us, "ليه X" when we hold their money.
String agentBalanceLabel(num balance) => balance > 0
    ? 'عليه ${money(balance)}'
    : balance < 0
    ? 'ليه ${money(-balance)}'
    : 'مسدد';

/// Loose key for matching agent names typed in Arabic: ignores case, extra
/// spaces and the usual alef / yaa / taa marbuta spelling differences.
String agentSearchKey(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه');

/// Chooses the agent an operation belongs to: either an existing agent with a
/// credit account (searched by any part of the name) or a brand-new agent.
///
/// The chosen or typed name is written to [controller]. [agents] are maps with
/// `agentName` and `balance` (positive = owes us, negative = deposit).
class AgentPicker extends StatefulWidget {
  const AgentPicker({
    super.key,
    required this.controller,
    required this.agents,
    this.enabled = true,
    this.label = 'المندوب *',
    this.fieldKey,
  });

  final TextEditingController controller;
  final List<dynamic> agents;
  final bool enabled;
  final String label;

  /// Key of the name text field in "new agent" mode (used by tests).
  final Key? fieldKey;

  @override
  State<AgentPicker> createState() => _AgentPickerState();
}

enum _AgentMode { existing, fresh }

class _AgentPickerState extends State<AgentPicker> {
  /// Null until the user picks a tab; then the default follows the data.
  _AgentMode? _chosenMode;
  TextEditingController? _search;

  _AgentMode get _mode =>
      _chosenMode ??
      (widget.agents.isEmpty ? _AgentMode.fresh : _AgentMode.existing);

  Map<String, dynamic>? _agentNamed(String name) {
    final key = agentSearchKey(name);
    if (key.isEmpty) return null;
    for (final agent in widget.agents) {
      if (agentSearchKey('${agent['agentName']}') == key) {
        return Map<String, dynamic>.from(agent as Map);
      }
    }
    return null;
  }

  void _setName(String name) {
    if (widget.controller.text == name) return;
    widget.controller.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
  }

  void _switchMode(_AgentMode mode) {
    setState(() {
      _chosenMode = mode;
      _search?.clear();
      _setName('');
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _mode == _AgentMode.existing
        ? _agentNamed(widget.controller.text)
        : null;
    return HesbaModalField(
      label: widget.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_AgentMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: _AgentMode.existing,
                icon: const Icon(Icons.person_search_outlined, size: 18),
                label: Text('مندوب قديم (${widget.agents.length})'),
                enabled: widget.agents.isNotEmpty,
              ),
              const ButtonSegment(
                value: _AgentMode.fresh,
                icon: Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: Text('مندوب جديد'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: widget.enabled
                ? (value) => _switchMode(value.first)
                : null,
          ),
          const SizedBox(height: 10),
          if (_mode == _AgentMode.existing) _existingField() else _newField(),
          if (_mode == _AgentMode.fresh &&
              _agentNamed(widget.controller.text) != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: widget.enabled
                    ? () {
                        final agent = _agentNamed(widget.controller.text)!;
                        setState(() {
                          _chosenMode = _AgentMode.existing;
                          _setName('${agent['agentName']}');
                        });
                      }
                    : null,
                icon: const Icon(Icons.info_outline, size: 18),
                label: Text(
                  'المندوب ده موجود: ${agentBalanceLabel(num.tryParse('${_agentNamed(widget.controller.text)!['balance']}') ?? 0)} — اضغط عشان تضيف على حسابه',
                ),
              ),
            ),
          if (selected != null) ...[
            const SizedBox(height: 6),
            Text(
              'الرصيد الحالي: ${agentBalanceLabel(num.tryParse('${selected['balance']}') ?? 0)} — العملية هتتحسب على نفس حسابه',
              style: HesbaText.caption,
            ),
          ],
        ],
      ),
    );
  }

  Widget _existingField() {
    return LayoutBuilder(
      builder: (context, constraints) => Autocomplete<Map<String, dynamic>>(
        key: const ValueKey('agent-search'),
        initialValue: TextEditingValue(text: widget.controller.text),
        displayStringForOption: (agent) => '${agent['agentName']}',
        optionsBuilder: (value) {
          final query = agentSearchKey(value.text);
          return widget.agents
              .map((agent) => Map<String, dynamic>.from(agent as Map))
              .where(
                (agent) =>
                    query.isEmpty ||
                    agentSearchKey('${agent['agentName']}').contains(query),
              );
        },
        onSelected: (agent) =>
            setState(() => _setName('${agent['agentName']}')),
        fieldViewBuilder: (context, search, focusNode, submit) {
          _search = search;
          return TextFormField(
            key: const ValueKey('agent-search-field'),
            controller: search,
            focusNode: focusNode,
            enabled: widget.enabled,
            decoration: const InputDecoration(
              hintText: 'دوّر باسم المندوب أو أي حرف منه',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (text) {
              // Only an agent picked from the list counts; typing alone keeps
              // the choice empty unless it matches an existing name exactly.
              final match = _agentNamed(text);
              setState(
                () => _setName(match == null ? '' : '${match['agentName']}'),
              );
            },
            validator: (_) => widget.controller.text.trim().isEmpty
                ? 'اختار المندوب من القايمة، أو دوس «مندوب جديد»'
                : null,
          );
        },
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: AlignmentDirectional.topStart,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 260,
                maxWidth: constraints.maxWidth,
              ),
              child: options.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('مفيش مندوب بالاسم ده'),
                    )
                  : ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        for (final agent in options)
                          ListTile(
                            dense: true,
                            title: Text('${agent['agentName']}'),
                            trailing: _BalanceBadge(
                              num.tryParse('${agent['balance']}') ?? 0,
                            ),
                            onTap: () => onSelected(agent),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _newField() {
    return TextFormField(
      key: widget.fieldKey,
      controller: widget.controller,
      enabled: widget.enabled,
      maxLength: 150,
      decoration: const InputDecoration(hintText: 'اكتب اسم المندوب الجديد'),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        final name = value?.trim() ?? '';
        if (name.isEmpty) return 'اكتب اسم المندوب';
        if (name.length < 2) return 'اسم المندوب لازم يكون حرفين على الأقل';
        final existing = _agentNamed(name);
        if (existing != null) {
          return '«${existing['agentName']}» موجود بالفعل؛ اختاره من «مندوب قديم» عشان يتضاف على حسابه';
        }
        return null;
      },
    );
  }
}

class _BalanceBadge extends StatelessWidget {
  const _BalanceBadge(this.balance);

  final num balance;

  @override
  Widget build(BuildContext context) {
    return Text(
      agentBalanceLabel(balance),
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: balance > 0
            ? HesbaColors.warning
            : balance < 0
            ? HesbaColors.tealDark
            : HesbaColors.muted,
      ),
    );
  }
}

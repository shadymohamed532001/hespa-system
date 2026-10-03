import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/datetime_formatter.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/page_frame.dart';
import '../auth/session_controller.dart';

class FawryTodayOperationsPage extends StatefulWidget {
  const FawryTodayOperationsPage({
    super.key,
    required this.session,
    required this.onBack,
  });

  final SessionController session;
  final VoidCallback onBack;

  @override
  State<FawryTodayOperationsPage> createState() =>
      _FawryTodayOperationsPageState();
}

class _FawryTodayOperationsPageState extends State<FawryTodayOperationsPage> {
  Map<String, dynamic>? _payload;
  List<Map<String, dynamic>> _accounts = [];
  String? _accountId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (mounted && !silent) setState(() => _loading = true);
    try {
      _payload = await widget.session.api.getMap(
        ApiEndpoints.fawryTodayOperations(accountId: _accountId),
      );
      _accounts = (_payload?['accounts'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (_accountId == null && _accounts.length == 1) {
        _accountId = '${_accounts.first['id']}';
      }
      _error = null;
    } catch (exception) {
      _error = ApiClient.errorMessage(exception);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _selectAccount(String? id) {
    if (id == null || id == _accountId) return;
    setState(() => _accountId = id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final waitingForAccount = _accounts.length > 1 && _accountId == null;
    final operations = waitingForAccount
        ? <Map<String, dynamic>>[]
        : (_payload?['operations'] as List? ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
    final done = operations
        .where((item) => item['status'] != 'reversed')
        .length;
    final reversed = operations.length - done;

    return PageFrame(
      onRefresh: () => _load(silent: true),
      title: 'عمليات فوري النهارده',
      subtitle: 'مراجعة معاملات حسابات فوري اللي حصلت النهارده',
      actions: [
        IconButton(
          tooltip: 'رجوع لحسابات فوري',
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        IconButton.filledTonal(
          tooltip: 'تحديث',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AccountPicker(
            accounts: _accounts,
            accountId: _accountId,
            onChanged: _loading ? null : _selectAccount,
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(80),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            ErrorBox(message: _error!, retry: _load)
          else ...[
            if (waitingForAccount)
              const _EmptyOperations(
                message: 'اختار حساب فوري عشان تشوف عملياته النهارده',
              )
            else ...[
              _SummaryBar(
                count: operations.length,
                done: done,
                reversed: reversed,
              ),
              const SizedBox(height: 16),
              if (operations.isEmpty)
                const _EmptyOperations(
                  message: 'مفيش معاملات على الحساب ده النهارده',
                )
              else
                for (final operation in operations) ...[
                  _OperationTile(operation: operation),
                  const SizedBox(height: 10),
                ],
            ],
          ],
        ],
      ),
    );
  }
}

class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    required this.accounts,
    required this.accountId,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> accounts;
  final String? accountId;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HesbaColors.border),
      ),
      child: DropdownButtonFormField<String>(
        key: ValueKey(accountId),
        initialValue: accountId,
        isExpanded: true,
        hint: Text(
          accounts.isEmpty ? 'مفيش حسابات فوري' : 'اختار الحساب',
          style: HesbaText.bodyMuted,
        ),
        decoration: const InputDecoration(labelText: 'الحساب'),
        items: [
          for (final account in accounts)
            DropdownMenuItem(
              value: '${account['id']}',
              child: Text('${account['name']}'),
            ),
        ],
        onChanged: accounts.isEmpty ? null : onChanged,
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.count,
    required this.done,
    required this.reversed,
  });

  final int count;
  final int done;
  final int reversed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HesbaColors.border),
      ),
      child: Row(
        children: [
          Text('عدد العمليات', style: HesbaText.sectionTitle),
          const Spacer(),
          _CountChip(label: 'تمت', value: done, color: const Color(0xFF1F9D55)),
          const SizedBox(width: 8),
          _CountChip(label: 'اتعكست', value: reversed, color: HesbaColors.red),
          const SizedBox(width: 14),
          Text('$count', style: HesbaText.pageTitle.copyWith(fontSize: 28)),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label $value',
        style: HesbaText.body.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyOperations extends StatelessWidget {
  const _EmptyOperations({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HesbaColors.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: HesbaText.bodyMuted,
      ),
    );
  }
}

class _OperationTile extends StatelessWidget {
  const _OperationTile({required this.operation});

  final Map<String, dynamic> operation;

  @override
  Widget build(BuildContext context) {
    final reversed = operation['status'] == 'reversed';
    final color = reversed ? HesbaColors.red : const Color(0xFF1F9D55);
    final reference = '${operation['reference'] ?? ''}'.trim();
    final account = '${operation['accountName'] ?? ''}'.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HesbaColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            reversed ? Icons.cancel : Icons.check_circle,
            color: color,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${operation['description']}',
                  style: HesbaText.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  reference.isEmpty ? '—' : reference,
                  style: HesbaText.bodyMuted,
                ),
                if (account.isNotEmpty) Text(account, style: HesbaText.caption),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatDate(operation['createdAt']),
                style: HesbaText.bodyMuted,
              ),
              const SizedBox(height: 4),
              Text(
                money(operation['amount']),
                style: HesbaText.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

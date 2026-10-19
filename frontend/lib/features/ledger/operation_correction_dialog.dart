import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/hesba_modal.dart';
import '../../core/theme/app_theme.dart';
import '../auth/session_controller.dart';

/// The server supplies business fields and recomputes every financial effect.
Future<bool> showOperationCorrection(
  BuildContext context,
  SessionController session,
  String entryId, {
  required bool cancel,
  String? basePath,
}) async {
  if (!session.isAdmin) return false;
  final path = basePath ?? '/ledger/$entryId';
  try {
    final form = await session.api.getMap('$path/correction');
    if (!context.mounted) return false;
    if (form['blocked'] != null) {
      showAppSnack(context, '${form['blocked']}', error: true);
      return false;
    }
    return await showHesbaModal<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _CorrectionDialog(
            session: session,
            path: path,
            form: form,
            cancel: cancel,
          ),
        ) ??
        false;
  } catch (e) {
    if (context.mounted) {
      showAppSnack(context, ApiClient.errorMessage(e), error: true);
    }
    return false;
  }
}

class _CorrectionDialog extends StatefulWidget {
  const _CorrectionDialog({
    required this.session,
    required this.path,
    required this.form,
    required this.cancel,
  });
  final SessionController session;
  final String path;
  final Map<String, dynamic> form;
  final bool cancel;
  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  final formKey = GlobalKey<FormState>();
  final reason = TextEditingController();
  final controllers = <String, TextEditingController>{};
  final values = <String, dynamic>{};
  bool saving = false;
  String? error;

  List<Map<String, dynamic>> get fields =>
      (widget.form['fields'] as List).cast<Map<String, dynamic>>();

  @override
  void initState() {
    super.initState();
    for (final field in fields) {
      final key = '${field['key']}';
      dynamic value = widget.form['values'];
      for (final part in key.split('.')) {
        value = value is List ? value[int.parse(part)] : value?[part];
      }
      values[key] = value;
      if (field['type'] == 'number' || field['type'] == 'text') {
        controllers[key] = TextEditingController(text: '${value ?? ''}');
      }
    }
  }

  @override
  void dispose() {
    reason.dispose();
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (saving || !formKey.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final submitted = <String, dynamic>{};
      if (!widget.cancel) {
        for (final field in fields) {
          final key = '${field['key']}';
          submitted[key] = switch (field['type']) {
            'number' => num.parse(controllers[key]!.text.trim()),
            'text' => controllers[key]!.text.trim(),
            _ => values[key],
          };
        }
      }
      await widget.session.api.post(
        '${widget.path}/${widget.cancel ? 'cancel' : 'correct'}',
        {'reason': reason.text.trim(), if (!widget.cancel) 'values': submitted},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = ApiClient.errorMessage(e);
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: HesbaModalCard(
      title: widget.cancel ? 'إلغاء العملية' : 'تعديل العملية',
      subtitle: '${widget.form['description']}',
      actions: HesbaModalActions(
        primaryLabel: saving
            ? 'جاري الحفظ…'
            : widget.cancel
            ? 'تأكيد إلغاء العملية'
            : 'حفظ التعديل',
        primaryEnabled: !saving,
        cancelEnabled: !saving,
        cancelLabel: 'رجوع',
        onPrimary: submit,
        onCancel: () => Navigator.pop(context, false),
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HesbaModalCallout(
              borderColor: HesbaColors.border,
              child: Text(
                widget.cancel
                    ? 'هيتم إرجاع تأثير العملية وكل أجزائها المرتبطة على الأرصدة والعمولات، مع الاحتفاظ بسجل الإلغاء.'
                    : 'هيتم إلغاء تأثير القيم القديمة وتسجيل القيم الصحيحة معًا. لو التعديل تعذّر، العملية القديمة هتفضل كما هي.',
              ),
            ),
            if (!widget.cancel)
              for (final field in fields)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: fieldWidget(field),
                ),
            const SizedBox(height: 18),
            HesbaModalField(
              label: 'سبب التصحيح',
              child: TextFormField(
                controller: reason,
                enabled: !saving,
                maxLength: 300,
                minLines: 2,
                maxLines: 3,
                validator: (v) => (v?.trim().length ?? 0) < 3
                    ? 'اكتب سبب واضح من ٣ حروف على الأقل'
                    : null,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              HesbaModalCallout(
                borderColor: HesbaColors.red,
                child: Text(
                  error!,
                  style: const TextStyle(color: HesbaColors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget fieldWidget(Map<String, dynamic> field) {
    final key = '${field['key']}';
    final label = '${field['label']}';
    if (field['type'] == 'boolean') {
      return HesbaModalCallout(
        backgroundColor: Colors.white,
        borderColor: HesbaColors.border,
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: HesbaText.fieldLabel),
          value: values[key] == true,
          onChanged: saving ? null : (v) => setState(() => values[key] = v),
        ),
      );
    }
    if (field['type'] == 'select') {
      final options = (field['options'] as List).cast<Map<String, dynamic>>();
      final current = '${values[key] ?? ''}';
      return HesbaModalField(
        label: label,
        child: DropdownButtonFormField<String>(
          initialValue: options.any((o) => o['value'] == current)
              ? current
              : null,
          isExpanded: true,
          items: options
              .map(
                (o) => DropdownMenuItem(
                  value: '${o['value']}',
                  child: Text('${o['label']}', overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: saving ? null : (v) => setState(() => values[key] = v),
          validator: (v) => v == null ? 'اختار $label' : null,
        ),
      );
    }
    return HesbaModalField(
      label: label,
      child: TextFormField(
        controller: controllers[key],
        enabled: !saving,
        keyboardType: field['type'] == 'number'
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        validator: (v) =>
            field['type'] == 'number' &&
                (num.tryParse(v?.trim() ?? '')?.isFinite != true)
            ? 'اكتب رقم صحيح'
            : null,
      ),
    );
  }
}

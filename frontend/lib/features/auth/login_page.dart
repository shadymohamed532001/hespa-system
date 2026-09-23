import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/hesba_modal.dart';
import 'session_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session});

  final SessionController session;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final username = TextEditingController();
  final password = TextEditingController();
  int _recoveryTapCount = 0;
  bool _recoveryVisible = false;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() => widget.session.login(username.text, password.text);

  void _recordRecoveryTap() {
    if (_recoveryVisible) return;
    _recoveryTapCount += 1;
    if (_recoveryTapCount < 5) return;
    setState(() => _recoveryVisible = true);
  }

  Future<void> _openAdminRecovery() async {
    final createdUsername = await showHesbaModal<String>(
      context: context,
      maxWidth: 520,
      barrierDismissible: false,
      builder: (context) => _AdminRecoveryDialog(api: widget.session.api),
    );
    if (!mounted || createdUsername == null) return;
    username.text = createdUsername;
    password.clear();
    showAppSnack(context, 'تم إنشاء المدير. يمكنك تسجيل الدخول الآن');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE9F0F3),
                    Color(0xFFF7F9FA),
                    Color(0xFFE6EFEF),
                  ],
                  stops: [0, 0.55, 1],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 28,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 470),
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: HesbaColors.border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x29102F3E),
                              blurRadius: 80,
                              offset: Offset(0, 28),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _LoginHeader(),
                            _LoginForm(
                              session: widget.session,
                              username: username,
                              password: password,
                              onSubmit: submit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                right: false,
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: _recoveryVisible
                      ? Center(
                          child: Tooltip(
                            message: 'استعادة حساب مدير',
                            child: IconButton.filledTonal(
                              onPressed: _openAdminRecovery,
                              icon: const Icon(
                                Icons.admin_panel_settings_outlined,
                              ),
                            ),
                          ),
                        )
                      : GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _recordRecoveryTap,
                          child: const SizedBox.expand(),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminRecoveryDialog extends StatefulWidget {
  const _AdminRecoveryDialog({required this.api});

  final ApiClient api;

  @override
  State<_AdminRecoveryDialog> createState() => _AdminRecoveryDialogState();
}

class _AdminRecoveryDialogState extends State<_AdminRecoveryDialog> {
  final recoveryKey = TextEditingController();
  final username = TextEditingController();
  final displayName = TextEditingController();
  final password = TextEditingController();
  final passwordConfirmation = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    recoveryKey.dispose();
    username.dispose();
    displayName.dispose();
    password.dispose();
    passwordConfirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final normalizedUsername = username.text.trim();
    final secret = recoveryKey.text;
    final newPassword = password.text;
    if (secret.isEmpty || normalizedUsername.isEmpty || newPassword.isEmpty) {
      setState(() => error = 'كود الاستعادة واسم المستخدم وكلمة المرور مطلوبة');
      return;
    }
    if (newPassword.length < 10) {
      setState(() => error = 'كلمة المرور يجب ألا تقل عن 10 أحرف');
      return;
    }
    if (newPassword != passwordConfirmation.text) {
      setState(() => error = 'كلمتا المرور غير متطابقتين');
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.recoverAdmin(
        recoveryKey: secret,
        username: normalizedUsername,
        displayName: displayName.text.trim().isEmpty
            ? normalizedUsername
            : displayName.text.trim(),
        password: newPassword,
      );
      if (!mounted) return;
      Navigator.pop(context, normalizedUsername);
    } catch (exception) {
      if (!mounted) return;
      setState(() => error = ApiClient.errorMessage(exception));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HesbaModalCard(
      title: 'إنشاء مدير استعادة',
      subtitle: 'سيحصل هذا الحساب على كل صلاحيات النظام',
      actions: HesbaModalActions(
        primaryLabel: busy ? 'جارٍ الإنشاء...' : 'إنشاء المدير',
        primaryEnabled: !busy,
        cancelEnabled: !busy,
        onPrimary: _submit,
        onCancel: () => Navigator.pop(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HesbaModalField(
            label: 'كود استعادة المدير *',
            child: _LoginTextField(
              controller: recoveryKey,
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: 15),
          HesbaModalField(
            label: 'اسم المستخدم *',
            child: _LoginTextField(
              controller: username,
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: 15),
          HesbaModalField(
            label: 'الاسم الظاهر',
            child: _LoginTextField(
              controller: displayName,
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: 15),
          HesbaModalField(
            label: 'كلمة المرور *',
            child: _LoginTextField(
              controller: password,
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: 15),
          HesbaModalField(
            label: 'تأكيد كلمة المرور *',
            child: _LoginTextField(
              controller: passwordConfirmation,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HesbaColors.redLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                error!,
                style: const TextStyle(color: HesbaColors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 134,
      color: HesbaColors.navy,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      alignment: Alignment.centerRight,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('حِسبة', style: HesbaText.loginBrand),
          SizedBox(height: 5),
          Text(
            'إدارة التحصيل والمدفوعات',
            style: TextStyle(
              fontFamily: HesbaText.family,
              color: Color(0x99FFFFFF),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.session,
    required this.username,
    required this.password,
    required this.onSubmit,
  });

  final SessionController session;
  final TextEditingController username;
  final TextEditingController password;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 32),
      child: AnimatedBuilder(
        animation: session,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('تسجيل الدخول', style: HesbaText.loginTitle),
              const SizedBox(height: 5),
              const Text(
                'أدخل اسم المستخدم وكلمة المرور للمتابعة.',
                style: HesbaText.bodyMuted,
              ),
              const SizedBox(height: 23),
              const _FieldLabel('اسم المستخدم'),
              const SizedBox(height: 8),
              _LoginTextField(
                controller: username,
                autofocus: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
              ),
              const SizedBox(height: 17),
              const _FieldLabel('كلمة المرور'),
              const SizedBox(height: 8),
              _LoginTextField(
                controller: password,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => onSubmit(),
              ),
              if (session.error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HesbaColors.redLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    session.error!,
                    style: const TextStyle(
                      color: HesbaColors.red,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: session.busy ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: HesbaColors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: session.busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'دخول إلى النظام',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 19),
              const _DemoAccounts(),
            ],
          );
        },
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: HesbaText.fieldLabel);
  }
}

class _LoginTextField extends StatefulWidget {
  const _LoginTextField({
    required this.controller,
    this.autofocus = false,
    this.obscureText = false,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final bool autofocus;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_LoginTextField> createState() => _LoginTextFieldState();
}

class _LoginTextFieldState extends State<_LoginTextField> {
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    focusNode.addListener(_handleFocus);
  }

  void _handleFocus() => setState(() {});

  @override
  void dispose() {
    focusNode
      ..removeListener(_handleFocus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: focused
            ? const [
                BoxShadow(
                  color: Color(0x330B8C7E),
                  blurRadius: 0,
                  spreadRadius: 4,
                ),
              ]
            : const [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: focusNode,
        autofocus: widget.autofocus,
        obscureText: widget.obscureText,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        onSubmitted: widget.onSubmitted,
        style: const TextStyle(
          color: HesbaColors.navy,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          border: _border(HesbaColors.border),
          enabledBorder: _border(const Color(0xFFD5E0E5)),
          focusedBorder: _border(HesbaColors.teal),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _DemoAccounts extends StatelessWidget {
  const _DemoAccounts();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'حسابات النسخة التجريبية',
              style: TextStyle(
                color: HesbaColors.navy,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'الأدمن: demo / demo',
              style: TextStyle(
                color: HesbaColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'موظف المحل: shix / shix',
              style: TextStyle(
                color: HesbaColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

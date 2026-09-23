import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/hesba_modal.dart';
import 'session_controller.dart';

/// Which entrance the user chose before typing credentials.
enum LoginPortal { admin, employee }

extension LoginPortalApi on LoginPortal {
  String get apiValue => this == LoginPortal.admin ? 'admin' : 'employee';

  String title(AppStrings t) =>
      this == LoginPortal.admin ? t.securityPortal : t.staffPortal;

  String subtitle(AppStrings t) => this == LoginPortal.admin
      ? t.securityPortalSubtitle
      : t.staffPortalSubtitle;

  String submitLabel(AppStrings t) =>
      this == LoginPortal.admin ? t.securitySignIn : t.staffSignIn;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session, required this.settings});

  final SessionController session;
  final AppSettings settings;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final username = TextEditingController();
  final password = TextEditingController();
  LoginPortal? _portal;
  int _recoveryTapCount = 0;
  bool _recoveryVisible = false;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() {
    final portal = _portal;
    if (portal == null) return Future.value();
    return widget.session.login(
      username.text,
      password.text,
      portal: portal.apiValue,
    );
  }

  void _openPortal(LoginPortal portal) {
    widget.session.clearError();
    setState(() {
      _portal = portal;
      _recoveryTapCount = 0;
      _recoveryVisible = false;
      username.clear();
      password.clear();
    });
  }

  void _backToPortals() {
    widget.session.clearError();
    setState(() {
      _portal = null;
      _recoveryTapCount = 0;
      _recoveryVisible = false;
      username.clear();
      password.clear();
    });
  }

  void _recordRecoveryTap() {
    if (_portal != LoginPortal.admin || _recoveryVisible) return;
    _recoveryTapCount += 1;
    if (_recoveryTapCount < 5) return;
    setState(() => _recoveryVisible = true);
  }

  Future<void> _openAdminRecovery() async {
    final createdUsername = await showHesbaModal<String>(
      context: context,
      maxWidth: 520,
      barrierDismissible: false,
      builder: (context) => _AdminRecoveryDialog(
        api: widget.session.api,
        strings: AppStrings.of(widget.settings.locale),
      ),
    );
    if (!mounted || createdUsername == null) return;
    username.text = createdUsername;
    password.clear();
    showAppSnack(context, AppStrings.of(widget.settings.locale).adminCreated);
  }

  @override
  Widget build(BuildContext context) {
    final portal = _portal;
    final t = AppStrings.of(widget.settings.locale);

    return Directionality(
      textDirection: widget.settings.textDirection,
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
                            _LoginHeader(
                              portal: portal,
                              strings: t,
                              onBack: portal == null ? null : _backToPortals,
                            ),
                            if (portal == null)
                              _PortalChooser(strings: t, onChoose: _openPortal)
                            else
                              _LoginForm(
                                session: widget.session,
                                portal: portal,
                                strings: t,
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
            if (portal == LoginPortal.admin)
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
                              message: t.recoverAdminTooltip,
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
  const _AdminRecoveryDialog({required this.api, required this.strings});

  final ApiClient api;
  final AppStrings strings;

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
    final t = widget.strings;
    final normalizedUsername = username.text.trim();
    final secret = recoveryKey.text;
    final newPassword = password.text;
    if (secret.isEmpty || normalizedUsername.isEmpty || newPassword.isEmpty) {
      setState(() => error = t.recoveryRequiredFields);
      return;
    }
    if (newPassword.length < 10) {
      setState(() => error = t.passwordTooShort);
      return;
    }
    if (newPassword != passwordConfirmation.text) {
      setState(() => error = t.passwordsMismatch);
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
      setState(
        () => error = ApiClient.errorMessage(
          exception,
          locale: t.localeCode,
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.strings;
    return HesbaModalCard(
      title: t.recoverAdminTitle,
      subtitle: t.recoverAdminSubtitle,
      actions: HesbaModalActions(
        primaryLabel: busy ? t.recoverAdminBusy : t.recoverAdminAction,
        primaryEnabled: !busy,
        cancelEnabled: !busy,
        onPrimary: _submit,
        onCancel: () => Navigator.pop(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HesbaModalField(
            label: t.recoveryKey,
            child: _LoginTextField(
              controller: recoveryKey,
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: 15),
          HesbaModalField(
            label: t.usernameRequired,
            child: _LoginTextField(
              controller: username,
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: 15),
          HesbaModalField(
            label: t.displayName,
            child: _LoginTextField(
              controller: displayName,
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: 15),
          HesbaModalField(
            label: t.passwordRequired,
            child: _LoginTextField(
              controller: password,
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: 15),
          HesbaModalField(
            label: t.passwordConfirm,
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
  const _LoginHeader({
    required this.portal,
    required this.strings,
    this.onBack,
  });

  final LoginPortal? portal;
  final AppStrings strings;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final backOnStart = strings.isArabic
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final brandOnEnd = strings.isArabic
        ? Alignment.centerRight
        : Alignment.centerLeft;

    return Container(
      width: double.infinity,
      height: 134,
      color: HesbaColors.navy,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        children: [
          if (onBack != null)
            Align(
              alignment: backOnStart,
              child: IconButton(
                onPressed: onBack,
                tooltip: strings.backToPortals,
                icon: Icon(
                  strings.isArabic ? Icons.arrow_forward : Icons.arrow_back,
                  color: Colors.white70,
                ),
              ),
            ),
          Align(
            alignment: brandOnEnd,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.brand, style: HesbaText.loginBrand),
                const SizedBox(height: 5),
                Text(
                  portal?.title(strings) ?? strings.brandSub,
                  style: const TextStyle(
                    fontFamily: HesbaText.family,
                    color: Color(0x99FFFFFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PortalChooser extends StatelessWidget {
  const _PortalChooser({required this.strings, required this.onChoose});

  final AppStrings strings;
  final ValueChanged<LoginPortal> onChoose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(strings.choosePortalTitle, style: HesbaText.loginTitle),
          const SizedBox(height: 5),
          Text(strings.choosePortalSubtitle, style: HesbaText.bodyMuted),
          const SizedBox(height: 24),
          _PortalCard(
            portal: LoginPortal.admin,
            strings: strings,
            icon: Icons.shield_outlined,
            onTap: () => onChoose(LoginPortal.admin),
          ),
          const SizedBox(height: 14),
          _PortalCard(
            portal: LoginPortal.employee,
            strings: strings,
            icon: Icons.storefront_outlined,
            onTap: () => onChoose(LoginPortal.employee),
          ),
        ],
      ),
    );
  }
}

class _PortalCard extends StatelessWidget {
  const _PortalCard({
    required this.portal,
    required this.strings,
    required this.icon,
    required this.onTap,
  });

  final LoginPortal portal;
  final AppStrings strings;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isAdmin = portal == LoginPortal.admin;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isAdmin ? HesbaColors.navy : const Color(0xFFF7F9FA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isAdmin ? HesbaColors.navy : HesbaColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isAdmin
                      ? const Color(0x331F8C7E)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isAdmin
                        ? const Color(0x44FFFFFF)
                        : HesbaColors.border,
                  ),
                ),
                child: Icon(
                  icon,
                  color: isAdmin ? Colors.white : HesbaColors.teal,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      portal.title(strings),
                      style: TextStyle(
                        fontFamily: HesbaText.family,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isAdmin ? Colors.white : HesbaColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      portal.subtitle(strings),
                      style: TextStyle(
                        fontFamily: HesbaText.family,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: isAdmin
                            ? const Color(0xB3FFFFFF)
                            : HesbaColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                strings.isArabic ? Icons.chevron_left : Icons.chevron_right,
                color: isAdmin ? Colors.white70 : HesbaColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.session,
    required this.portal,
    required this.strings,
    required this.username,
    required this.password,
    required this.onSubmit,
  });

  final SessionController session;
  final LoginPortal portal;
  final AppStrings strings;
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
              Text(portal.title(strings), style: HesbaText.loginTitle),
              const SizedBox(height: 5),
              Text(portal.subtitle(strings), style: HesbaText.bodyMuted),
              const SizedBox(height: 23),
              _FieldLabel(strings.username),
              const SizedBox(height: 8),
              _LoginTextField(
                controller: username,
                autofocus: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
              ),
              const SizedBox(height: 17),
              _FieldLabel(strings.password),
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
                      : Text(
                          portal.submitLabel(strings),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 19),
              _DemoAccounts(portal: portal, strings: strings),
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
  const _DemoAccounts({required this.portal, required this.strings});

  final LoginPortal portal;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final isAdmin = portal == LoginPortal.admin;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              strings.demoAccounts,
              style: const TextStyle(
                color: HesbaColors.navy,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              isAdmin ? strings.demoSecurityAccount : strings.demoStaffAccount,
              style: const TextStyle(
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

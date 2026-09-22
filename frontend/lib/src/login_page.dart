import 'package:flutter/material.dart';

import 'session.dart';
import 'theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session});
  final SessionController session;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final username = TextEditingController(text: 'demo');
  final password = TextEditingController(text: 'demo');
  bool hidden = true;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() => widget.session.login(username.text, password.text);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            if (constraints.maxWidth >= 1000)
              Expanded(
                flex: 5,
                child: Container(
                  color: HesbaColors.navy,
                  padding: const EdgeInsets.all(54),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: HesbaColors.teal,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'حِسبة',
                          style: TextStyle(
                            fontSize: 54,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'إدارة التحصيل والمدفوعات',
                          style: TextStyle(
                            fontSize: 22,
                            color: Color(0xFFB7C8D0),
                          ),
                        ),
                        const SizedBox(height: 48),
                        _feature(
                          Icons.verified_user_outlined,
                          'صلاحيات منفصلة للمدير والمستخدم',
                        ),
                        _feature(
                          Icons.sync_alt_rounded,
                          'متابعة الخزنة والحسابات لحظيًا',
                        ),
                        _feature(
                          Icons.receipt_long_outlined,
                          'سجل واضح لكل حركة وعمولة',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              flex: 6,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(48),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: AnimatedBuilder(
                      animation: widget.session,
                      builder: (context, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'تسجيل الدخول',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'أدخل بيانات الحساب للوصول إلى النظام',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: HesbaColors.muted),
                          ),
                          const SizedBox(height: 34),
                          const Text(
                            'اسم المستخدم',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: username,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.person_outline),
                              hintText: 'اسم المستخدم',
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'كلمة المرور',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: password,
                            obscureText: hidden,
                            onSubmitted: (_) => submit(),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock_outline),
                              hintText: 'كلمة المرور',
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => hidden = !hidden),
                                icon: Icon(
                                  hidden
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          if (widget.session.error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEEEE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                widget.session.error!,
                                style: const TextStyle(
                                  color: Color(0xFFB42318),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 26),
                          FilledButton(
                            onPressed: widget.session.busy ? null : submit,
                            child: widget.session.busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('دخول إلى حِسبة'),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'للتجربة: المدير demo / demo — المستخدم shix / shix',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: HesbaColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feature(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF8ED3CA)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ],
    ),
  );
}

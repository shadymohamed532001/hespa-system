import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
  });
  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(34, 34, 34, 48),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: HesbaText.pageTitle),
                  const SizedBox(height: 5),
                  Text(subtitle, style: HesbaText.bodyMuted),
                ],
              ),
            ),
            ...actions.map(
              (e) =>
                  Padding(padding: const EdgeInsets.only(right: 10), child: e),
            ),
          ],
        ),
        const SizedBox(height: 25),
        child,
      ],
    ),
  );
}

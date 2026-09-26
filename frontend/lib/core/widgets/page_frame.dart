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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The content area can still be narrow on a desktop window because the
        // persistent sidebar occupies part of the viewport. Base the header on
        // the space PageFrame actually receives instead of the device type.
        final isCompact = constraints.maxWidth < 800;
        final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 34.0;
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: HesbaText.pageTitle.copyWith(
                fontSize: isCompact ? 30 : null,
              ),
            ),
            const SizedBox(height: 5),
            Text(subtitle, style: HesbaText.bodyMuted),
          ],
        );
        final actionBar = Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actions,
        );

        final header = isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  titleBlock,
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    actionBar,
                  ],
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: titleBlock),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(width: 24),
                    Flexible(flex: 2, child: actionBar),
                  ],
                ],
              );

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            isCompact ? 24 : 34,
            horizontalPadding,
            48,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [header, const SizedBox(height: 25), child],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

void showAppSnack(BuildContext context, String message, {bool error = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFB42318) : HesbaColors.teal,
      ),
    );

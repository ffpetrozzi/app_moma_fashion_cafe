import 'package:flutter/material.dart';

enum AppSnackBarType { success, info, warning, error }

class AppSnackBar {
  static void show(
    BuildContext context,
    String message, {
    AppSnackBarType type = AppSnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground, icon) = _styleFor(type, scheme);

    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      duration: duration,
      showCloseIcon: true,
      closeIconColor: foreground,
      backgroundColor: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 28,
            width: 28,
            decoration: BoxDecoration(
              color: foreground.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: foreground, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  static (Color background, Color foreground, IconData icon) _styleFor(
    AppSnackBarType type,
    ColorScheme scheme,
  ) {
    switch (type) {
      case AppSnackBarType.success:
        return (scheme.secondaryContainer, scheme.onSecondaryContainer, Icons.check_rounded);
      case AppSnackBarType.warning:
        return (scheme.tertiaryContainer, scheme.onTertiaryContainer, Icons.warning_rounded);
      case AppSnackBarType.error:
        return (scheme.errorContainer, scheme.onErrorContainer, Icons.error_rounded);
      case AppSnackBarType.info:
        return (scheme.primaryContainer, scheme.onPrimaryContainer, Icons.info_rounded);
    }
  }
}

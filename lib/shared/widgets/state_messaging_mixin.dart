import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';

/// Shared SnackBar + `setState` helpers for [State] classes.
///
/// Consolidates the `_showMessage`/`_refresh` pair that used to be
/// copy-pasted across `lib/features/*` pages, widgets and dialogs.
mixin StateMessaging<T extends StatefulWidget> on State<T> {
  /// Shows a SnackBar with [text]. Set [isError] to tint it red.
  void showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? FncColors.materialRed.shade700 : null,
      ),
    );
  }

  /// Shorthand for `setState(update)`.
  void refresh(VoidCallback update) => setState(update);
}

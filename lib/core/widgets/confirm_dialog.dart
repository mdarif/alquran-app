import 'package:flutter/material.dart';

/// A Cancel/confirm dialog for an action that shouldn't happen by accident.
///
/// Returns `true` only if the reader explicitly tapped [confirmLabel] — a
/// cancel, a tap outside, or the system back gesture all resolve to `false`.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final cs = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: destructive
              ? TextButton.styleFrom(foregroundColor: cs.error)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

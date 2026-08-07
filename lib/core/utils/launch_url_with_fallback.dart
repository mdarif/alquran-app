import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [uri] externally; if the platform can't handle it (no Play Store,
/// no browser, intent resolution failure), falls back to a snackbar with a
/// "Copy link" action instead of failing silently.
Future<void> launchUrlWithFallback(
  BuildContext context,
  Uri uri, {
  String? failureMessage,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  bool ok;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (ok) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(failureMessage ?? 'Couldn’t open ${uri.host}'),
        action: SnackBarAction(
          label: 'Copy link',
          onPressed: () =>
              Clipboard.setData(ClipboardData(text: uri.toString())),
        ),
      ),
    );
}

import 'package:flutter/material.dart';
import 'package:offmoney/presentation/l10n/generated/app_localizations.dart';
import 'package:offmoney/presentation/shared/failure.dart';
import 'package:offmoney/presentation/shared/navigation.dart';

Future<void> runFormAction(
  BuildContext context, {
  required Future<bool> Function() action,
  required String doneMessage,
  required ValueChanged<bool> onBusyChanged,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  onBusyChanged(true);
  var done = false;
  try {
    done = await action();
  } on Exception catch (error, stack) {
    reportFailure(messenger, l10n.actionFailed, error, stack);
  } finally {
    if (!done && context.mounted) onBusyChanged(false);
  }
  if (!done || !context.mounted) return;
  popIfCurrent(context);
  messenger.showSnackBar(SnackBar(content: Text(doneMessage)));
}

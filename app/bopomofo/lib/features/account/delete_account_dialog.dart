import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  bool _deleteLocalData = false;

  @override
  Widget build(BuildContext context) {
    final labels = AppLocalizations.of(context)!;
    return AlertDialog(
        title: Text(labels.deleteAccountConfirmation),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(labels.deleteAccountExplanation),
            CheckboxListTile(
              key: const ValueKey('delete-local-data'),
              contentPadding: EdgeInsets.zero,
              value: _deleteLocalData,
              onChanged: (value) => setState(() => _deleteLocalData = value ?? false),
              title: Text(labels.deleteLocalDataToo),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(labels.cancel)),
          FilledButton(
            key: const ValueKey('confirm-delete-account'),
            onPressed: () => Navigator.pop(context, _deleteLocalData),
            child: Text(labels.deleteAccount),
          ),
        ],
      );
  }
}

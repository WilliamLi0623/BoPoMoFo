import 'package:flutter/material.dart';

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  bool _deleteLocalData = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Delete account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This permanently requests deletion of the cloud account.'),
            CheckboxListTile(
              key: const ValueKey('delete-local-data'),
              contentPadding: EdgeInsets.zero,
              value: _deleteLocalData,
              onChanged: (value) => setState(() => _deleteLocalData = value ?? false),
              title: const Text('Delete local learning data too'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('confirm-delete-account'),
            onPressed: () => Navigator.pop(context, _deleteLocalData),
            child: const Text('Delete account'),
          ),
        ],
      );
}

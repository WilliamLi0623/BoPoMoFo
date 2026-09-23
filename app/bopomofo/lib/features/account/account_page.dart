import 'package:auth/auth.dart';
import 'package:flutter/material.dart';

import '../../bootstrap.dart';
import 'delete_account_dialog.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({required this.authService, required this.repository, this.onReturnedToGuest, super.key});

  final AuthService authService;
  final AppLearningRepository repository;
  final VoidCallback? onReturnedToGuest;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String? _status;

  Future<void> _delete() async {
    final deleteLocalData = await showDialog<bool>(
      context: context,
      builder: (_) => const DeleteAccountDialog(),
    );
    if (deleteLocalData == null) return;
    try {
      await widget.authService.deleteAccount();
      if (deleteLocalData) await widget.repository.local.clearLocalData();
      await widget.authService.signOut();
      final returnToGuest = widget.onReturnedToGuest;
      if (returnToGuest != null) {
        returnToGuest();
        if (mounted) Navigator.of(context).pop();
      } else if (mounted) {
        setState(() => _status = deleteLocalData ? 'Account deleted and local data cleared.' : 'Account deleted. Local progress remains.');
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Account deletion failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Account', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(widget.authService.currentUser?.email ?? 'Guest / local account'),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            key: const ValueKey('account-delete'),
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete account'),
          ),
          if (_status != null) Text(_status!, key: const ValueKey('account-status')),
        ],
      );
}

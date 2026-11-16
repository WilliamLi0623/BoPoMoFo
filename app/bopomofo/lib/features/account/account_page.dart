import 'package:auth/auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../bootstrap.dart';
import '../../l10n/app_localizations.dart';
import 'delete_account_dialog.dart';

enum _DeleteStatus { deleted, deletedWithLocalData, failed }

class AccountPage extends StatefulWidget {
  const AccountPage({required this.authService, required this.repository, this.onReturnedToGuest, super.key});

  final AuthService authService;
  final AppLearningRepository repository;
  final VoidCallback? onReturnedToGuest;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  _DeleteStatus? _status;

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
        setState(() => _status = deleteLocalData ? _DeleteStatus.deletedWithLocalData : _DeleteStatus.deleted);
      }
    } catch (_) {
      if (mounted) setState(() => _status = _DeleteStatus.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = AppLocalizations.of(context)!;
    final statusText = switch (_status) {
      _DeleteStatus.deleted => labels.accountDeleted,
      _DeleteStatus.deletedWithLocalData => labels.accountDeletedWithLocalData,
      _DeleteStatus.failed => labels.accountDeletionUnavailable,
      null => null,
    };
    return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(labels.account, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(widget.authService.currentUser?.email ?? labels.guestLocalAccount),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            key: const ValueKey('account-delete'),
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
            label: Text(labels.deleteAccount),
          ),
          if (statusText != null) Text(statusText, key: const ValueKey('account-status')),
        ],
      );
  }
}

import 'package:auth/auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../bootstrap.dart';
import '../../l10n/app_localizations.dart';
import 'delete_account_dialog.dart';

enum _DeleteStatus { deleted, deletedWithLocalData, failed }

class AccountPage extends StatefulWidget {
  const AccountPage(
      {required this.authService,
      required this.repository,
      this.onReturnedToGuest,
      super.key});

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
        setState(() => _status = deleteLocalData
            ? _DeleteStatus.deletedWithLocalData
            : _DeleteStatus.deleted);
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = widget.authService.signedInUser;
    return Scaffold(
      appBar: AppBar(title: Text(labels.account)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  color: colors.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: colors.primaryContainer,
                          foregroundColor: colors.onPrimaryContainer,
                          child: const Icon(Icons.person_outline),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user == null
                                    ? labels.guestLocalAccount
                                    : labels.accountSignedInState,
                                style: theme.textTheme.titleMedium,
                              ),
                              if (user == null || user.email != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  user?.email ?? labels.progressSavedLocally,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(labels.accountDataManagement,
                    style: theme.textTheme.titleMedium),
                if (user != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    labels.deleteAccountExplanation,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    key: const ValueKey('account-delete'),
                    onPressed: _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.onSurface,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(labels.deleteAccount),
                  ),
                ),
                if (statusText != null) ...[
                  const SizedBox(height: 12),
                  Text(statusText, key: const ValueKey('account-status')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

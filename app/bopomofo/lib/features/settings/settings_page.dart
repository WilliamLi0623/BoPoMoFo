import 'package:material_ui/material_ui.dart';
import 'package:auth/auth.dart';
import 'package:sync/sync.dart' show SyncStatus;
import '../../bootstrap.dart';
import '../account/account_page.dart';
import '../../l10n/app_localizations.dart';
import '../../localization/app_locale_controller.dart';

enum _SettingsStatus {
  syncLocalOnly, syncPending, syncSynced, syncOffline, syncAccountMismatch, syncError,
  signedOut, signOutFailed, signInStarted, signInComplete, signInCancelled, signInFailed,
  exportReady, exportFailed, importEmpty, importComplete, importFailed,
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.authService, required this.syncService, required this.repository, required this.localeController, this.onReturnedToGuest, this.onExportReady, super.key});

  final AuthService authService;
  final SyncService syncService;
  final AppLearningRepository repository;
  final AppLocaleController localeController;
  final VoidCallback? onReturnedToGuest;
  final ValueChanged<String>? onExportReady;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _importController = TextEditingController();
  _SettingsStatus? _status;
  int _exportBytes = 0;
  bool _busy = false;
  bool _languageSaveFailed = false;
  int _languageSelectionGeneration = 0;

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    setState(() { _busy = true; _status = null; });
    try {
      final result = await widget.syncService.syncNow();
      if (mounted) {
        setState(() => _status = switch (result.status) {
          SyncStatus.localOnly => _SettingsStatus.syncLocalOnly,
          SyncStatus.pending => _SettingsStatus.syncPending,
          SyncStatus.synced => _SettingsStatus.syncSynced,
          SyncStatus.offline => _SettingsStatus.syncOffline,
          SyncStatus.accountMismatch => _SettingsStatus.syncAccountMismatch,
          SyncStatus.error => _SettingsStatus.syncError,
        });
      }
    } catch (_) {
      if (mounted) setState(() => _status = _SettingsStatus.syncError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() { _busy = true; _status = null; });
    try {
      await widget.authService.signOut();
      if (mounted) setState(() => _status = _SettingsStatus.signedOut);
    } catch (_) {
      if (mounted) setState(() => _status = _SettingsStatus.signOutFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    try {
      final data = await widget.repository.exportLearningData();
      widget.onExportReady?.call(data);
      if (mounted) setState(() { _exportBytes = data.length; _status = _SettingsStatus.exportReady; });
    } catch (_) {
      if (mounted) setState(() => _status = _SettingsStatus.exportFailed);
    }
  }

  Future<void> _import() async {
    final source = _importController.text.trim();
    if (source.isEmpty) {
      setState(() => _status = _SettingsStatus.importEmpty);
      return;
    }
    try {
      await widget.repository.importLearningData(source);
      if (mounted) setState(() => _status = _SettingsStatus.importComplete);
    } catch (_) {
      if (mounted) setState(() => _status = _SettingsStatus.importFailed);
    }
  }

  Future<void> _signIn() async {
    setState(() { _busy = true; _status = null; });
    try {
      final user = await widget.authService.signInWithGoogle();
      if (mounted) {
        setState(() => _status = user == null
            ? _SettingsStatus.signInStarted : _SettingsStatus.signInComplete);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status = error is AuthFailure && error.kind == AuthFailureKind.cancelled
            ? _SettingsStatus.signInCancelled : _SettingsStatus.signInFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = AppLocalizations.of(context)!;
    final statusText = switch (_status) {
      _SettingsStatus.syncLocalOnly => labels.syncLocalOnly,
      _SettingsStatus.syncPending => labels.syncPending,
      _SettingsStatus.syncSynced => labels.syncComplete,
      _SettingsStatus.syncOffline => labels.syncOffline,
      _SettingsStatus.syncAccountMismatch => labels.syncAccountMismatch,
      _SettingsStatus.syncError => labels.syncFailed,
      _SettingsStatus.signedOut => labels.signOutComplete,
      _SettingsStatus.signOutFailed => labels.signOutUnavailable,
      _SettingsStatus.signInStarted => labels.googleSignInStarted,
      _SettingsStatus.signInComplete => labels.googleSignInComplete,
      _SettingsStatus.signInCancelled => labels.googleSignInCancelled,
      _SettingsStatus.signInFailed => labels.googleSignInUnavailable,
      _SettingsStatus.exportReady => labels.exportReady(_exportBytes),
      _SettingsStatus.exportFailed => labels.exportUnavailable,
      _SettingsStatus.importEmpty => labels.importEmpty,
      _SettingsStatus.importComplete => labels.importComplete,
      _SettingsStatus.importFailed => labels.importUnavailable,
      null => null,
    };
    return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(labels.settings, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(labels.language),
          DropdownButton<Locale>(
            key: const ValueKey('settings-language'),
            value: widget.localeController.locale,
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
                child: Text(labels.simplifiedChinese),
              ),
              DropdownMenuItem(
                value: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
                child: Text(labels.traditionalChinese),
              ),
              DropdownMenuItem(
                value: const Locale('en'),
                child: Text(labels.english),
              ),
            ],
            onChanged: (locale) async {
              if (locale == null) return;
              final generation = ++_languageSelectionGeneration;
              final saved = await widget.localeController.select(locale);
              if (mounted && generation == _languageSelectionGeneration) {
                setState(() => _languageSaveFailed = !saved);
              }
            },
          ),
          if (_languageSaveFailed)
            Text(
              labels.languageNotSaved,
              key: const ValueKey('language-save-warning'),
            ),
          Text(labels.progressSavedLocally),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              key: const ValueKey('settings-account'),
              title: Text(labels.account),
              subtitle: Text(switch (widget.authService.signedInUser) {
                final user? => labels.signedInAccount(user.email ?? user.id),
                null => labels.guestModeProgress,
              }),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AccountPage(
                  authService: widget.authService,
                  repository: widget.repository,
                  onReturnedToGuest: widget.onReturnedToGuest,
                ),
              )),
            ),
          ),
          ListTile(leading: const Icon(Icons.login), title: Text(labels.googleSignIn), onTap: _busy ? null : _signIn),
          ListTile(leading: const Icon(Icons.sync), title: Text(labels.syncNow), onTap: _busy ? null : _sync),
          ListTile(leading: const Icon(Icons.logout), title: Text(labels.signOut), onTap: _busy ? null : _signOut),
          ListTile(leading: const Icon(Icons.upload_file), title: Text(labels.exportProgress), onTap: _busy ? null : _export),
          TextField(controller: _importController, decoration: InputDecoration(labelText: labels.importJson, hintText: labels.importHint)),
          ListTile(leading: const Icon(Icons.download), title: Text(labels.importProgress), onTap: _busy ? null : _import),
          ListTile(leading: const Icon(Icons.delete_outline), title: Text(labels.deleteAccount), onTap: _busy ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AccountPage(authService: widget.authService, repository: widget.repository, onReturnedToGuest: widget.onReturnedToGuest)))),
          if (statusText != null) Card(key: const ValueKey('settings-status'), child: ListTile(leading: const Icon(Icons.info_outline), title: Text(statusText))),
        ],
      );
  }
}

import 'package:flutter/material.dart';
import 'package:auth/auth.dart';
import '../../bootstrap.dart';
import '../account/account_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.authService, required this.syncService, required this.repository, this.onReturnedToGuest, this.onExportReady, super.key});

  final AuthService authService;
  final SyncService syncService;
  final AppLearningRepository repository;
  final VoidCallback? onReturnedToGuest;
  final ValueChanged<String>? onExportReady;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _importController = TextEditingController();
  String? _status;
  bool _busy = false;

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    setState(() { _busy = true; _status = null; });
    try {
      final result = await widget.syncService.syncNow();
      if (mounted) setState(() => _status = result.message ?? 'Sync status: ${result.status.name}.');
    } catch (error) {
      if (mounted) setState(() => _status = 'Sync unavailable: $error. Progress remains saved locally.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() { _busy = true; _status = null; });
    try {
      await widget.authService.signOut();
      if (mounted) setState(() => _status = 'Signed out. Local progress remains available.');
    } catch (error) {
      if (mounted) setState(() => _status = 'Sign out failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    try {
      final data = await widget.repository.exportLearningData();
      widget.onExportReady?.call(data);
      if (mounted) setState(() => _status = 'Export ready (${data.length} bytes).');
    } catch (error) {
      if (mounted) setState(() => _status = 'Export unavailable: $error');
    }
  }

  Future<void> _import() async {
    final source = _importController.text.trim();
    if (source.isEmpty) {
      setState(() => _status = 'Import unavailable: choose an exported JSON file first.');
      return;
    }
    try {
      await widget.repository.importLearningData(source);
      if (mounted) setState(() => _status = 'Progress imported and projections rebuilt.');
    } catch (error) {
      if (mounted) setState(() => _status = 'Import failed: $error. Existing progress was preserved.');
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          const Text('Progress is saved locally.'),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              key: const ValueKey('settings-account'),
              title: const Text('Account'),
              subtitle: const Text('Guest mode · local progress'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AccountPage(
                  authService: widget.authService,
                  repository: widget.repository,
                  onReturnedToGuest: widget.onReturnedToGuest,
                ),
              )),
            ),
          ),
          ListTile(leading: const Icon(Icons.login), title: const Text('Sign in with Google'), onTap: _busy ? null : () async {
            try { await widget.authService.signInWithGoogle(); setState(() => _status = 'Google sign-in complete.'); } catch (error) { setState(() => _status = 'Google sign-in unavailable: $error'); }
          }),
          ListTile(leading: const Icon(Icons.sync), title: const Text('Sync now'), onTap: _busy ? null : _sync),
          ListTile(leading: const Icon(Icons.logout), title: const Text('Sign out'), onTap: _busy ? null : _signOut),
          ListTile(leading: const Icon(Icons.upload_file), title: const Text('Export progress'), onTap: _busy ? null : _export),
          TextField(controller: _importController, decoration: const InputDecoration(labelText: 'Import JSON', hintText: 'Paste a Bopomofo export here')),
          ListTile(leading: const Icon(Icons.download), title: const Text('Import progress'), onTap: _busy ? null : _import),
          ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete account'), onTap: _busy ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AccountPage(authService: widget.authService, repository: widget.repository, onReturnedToGuest: widget.onReturnedToGuest)))),
          if (_status != null) Card(key: const ValueKey('settings-status'), child: ListTile(leading: const Icon(Icons.info_outline), title: Text(_status!))),
        ],
      );
}

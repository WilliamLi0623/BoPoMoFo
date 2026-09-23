import 'package:flutter/material.dart';
import 'package:auth/auth.dart';
import '../../bootstrap.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.learningEngine, required this.authService, required this.syncService, required this.repository, required this.onPathSelected, super.key});

  final LearningEngine learningEngine;
  final AuthService authService;
  final SyncService syncService;
  final AppLearningRepository repository;
  final ValueChanged<String> onPathSelected;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  String? _authMessage;
  bool _authBusy = false;

  Future<void> _signInWithGoogle() async {
    setState(() { _authBusy = true; _authMessage = null; });
    try {
      await widget.authService.signInWithGoogle();
      if (mounted) setState(() => _authMessage = 'Google sign-in complete.');
    } catch (error) {
      if (mounted) setState(() => _authMessage = 'Google sign-in unavailable: $error');
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Learn Bopomofo from what you already know.', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          const Text('Choose a starting point. You can change your path later.'),
          const SizedBox(height: 8),
          const Text('Guest mode · saved locally'),
          const SizedBox(height: 20),
          OutlinedButton(key: const ValueKey('start-learning'), onPressed: () => widget.onPathSelected('pinyin'), child: const Text('Start Learning')),
          const SizedBox(height: 12),
          _PathButton(key: const ValueKey('path-pinyin'), label: 'Start with Pinyin', onPressed: () => widget.onPathSelected('pinyin')),
          _PathButton(key: const ValueKey('path-sounds'), label: 'Start with sounds', onPressed: () => widget.onPathSelected('sounds')),
          _PathButton(key: const ValueKey('path-beginner'), label: 'I am new to Chinese', onPressed: () => widget.onPathSelected('beginner')),
          OutlinedButton(onPressed: _authBusy ? null : _signInWithGoogle, child: Text(_authBusy ? 'Signing in…' : 'Sign in with Google')),
          if (_authMessage != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_authMessage!, key: const ValueKey('auth-status'))),
          const SizedBox(height: 20),
          const Card(child: ListTile(leading: Icon(Icons.cloud_off), title: Text('Progress is saved locally.'), subtitle: Text('You can keep learning offline and sync later.'))),
        ],
      );
}

class _PathButton extends StatelessWidget {
  const _PathButton({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FilledButton(onPressed: onPressed, child: Text(label)),
      );
}

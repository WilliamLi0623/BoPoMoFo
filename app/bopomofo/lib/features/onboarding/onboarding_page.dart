import 'package:material_ui/material_ui.dart';
import 'package:auth/auth.dart';
import '../../bootstrap.dart';
import '../../l10n/app_localizations.dart';
import '../lesson/learning_path.dart';

enum _SignInStatus { started, complete, cancelled, unavailable }

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.learningEngine, required this.authService, required this.syncService, required this.repository, required this.onPathSelected, super.key});

  final LearningEngine learningEngine;
  final AuthService authService;
  final SyncService syncService;
  final AppLearningRepository repository;
  final ValueChanged<LearningPath> onPathSelected;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  _SignInStatus? _authStatus;
  bool _authBusy = false;

  Future<void> _signInWithGoogle() async {
    setState(() { _authBusy = true; _authStatus = null; });
    try {
      final user = await widget.authService.signInWithGoogle();
      if (mounted) {
        setState(() => _authStatus =
            user == null ? _SignInStatus.started : _SignInStatus.complete);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _authStatus = error is AuthFailure && error.kind == AuthFailureKind.cancelled
              ? _SignInStatus.cancelled
              : _SignInStatus.unavailable;
        });
      }
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = AppLocalizations.of(context)!;
    final authMessage = switch (_authStatus) {
      _SignInStatus.started => labels.googleSignInStarted,
      _SignInStatus.complete => labels.googleSignInComplete,
      _SignInStatus.cancelled => labels.googleSignInCancelled,
      _SignInStatus.unavailable => labels.googleSignInUnavailable,
      null => null,
    };
    return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(labels.onboardingTitle, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(labels.onboardingIntro),
          const SizedBox(height: 8),
          Text(
            key: const ValueKey('account-mode'),
            switch (widget.authService.signedInUser) {
              final user? => labels.signedInAccount(user.email ?? user.id),
              null => labels.guestModeLocal,
            },
          ),
          const SizedBox(height: 20),
          OutlinedButton(key: const ValueKey('start-learning'), onPressed: () => widget.onPathSelected(LearningPath.pinyin), child: Text(labels.startLearning)),
          const SizedBox(height: 12),
          _PathButton(key: const ValueKey('path-pinyin'), label: labels.pathPinyin, onPressed: () => widget.onPathSelected(LearningPath.pinyin)),
          _PathButton(key: const ValueKey('path-sounds'), label: labels.pathSounds, onPressed: () => widget.onPathSelected(LearningPath.sounds)),
          _PathButton(key: const ValueKey('path-beginner'), label: labels.pathBeginner, onPressed: () => widget.onPathSelected(LearningPath.beginner)),
          OutlinedButton(onPressed: _authBusy ? null : _signInWithGoogle, child: Text(_authBusy ? labels.signingIn : labels.googleSignIn)),
          if (authMessage != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(authMessage, key: const ValueKey('auth-status'))),
          const SizedBox(height: 20),
          Card(child: ListTile(leading: const Icon(Icons.cloud_off), title: Text(labels.progressSavedLocally), subtitle: Text(labels.offlineLearningSyncLater))),
        ],
      );
  }
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

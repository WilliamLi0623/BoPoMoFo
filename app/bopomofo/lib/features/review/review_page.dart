import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:learning_engine/learning_engine.dart';

import '../../l10n/app_localizations.dart';
import 'audio_prompt_player.dart';
import 'question_view.dart';

typedef ReviewSessionFactory = Future<ReviewSessionRuntime> Function();

class ReviewSessionRuntime {
  const ReviewSessionRuntime(
      {required this.coordinator, required this.audioPlayer});
  final QuizSessionCoordinator coordinator;
  final AudioPromptPlayer audioPlayer;
}

class ReviewPage extends StatefulWidget {
  const ReviewPage(
      {required this.sessionFactory, this.onReturnToLearning, super.key});
  final ReviewSessionFactory sessionFactory;
  final VoidCallback? onReturnToLearning;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  ReviewSessionRuntime? _runtime;
  QuizSession? _session;
  bool _loading = true;
  bool _busy = false;
  bool _error = false;
  int _questionGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final runtime = _runtime ?? await widget.sessionFactory();
      if (!mounted) {
        await runtime.audioPlayer.dispose();
        return;
      }
      _runtime = runtime;
      final session = await runtime.coordinator.loadOrStartSession();
      if (mounted) {
        setState(() {
          _session = session;
          _loading = false;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  Future<void> _submit(String response) async {
    final runtime = _runtime;
    if (_busy || runtime == null) return;
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      final session = await runtime.coordinator.submitAnswer(response);
      if (mounted) {
        setState(() {
          _session = session;
          _busy = false;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = true;
          _questionGeneration++;
        });
      }
    }
  }

  Future<void> _continue() async {
    final runtime = _runtime;
    if (_busy || runtime == null) return;
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      final session = await runtime.coordinator.continueSession();
      if (mounted) {
        setState(() {
          _session = session;
          _busy = false;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = true;
        });
      }
    }
  }

  Future<void> _retry() async {
    if (_runtime == null || _session == null) {
      await _load();
      return;
    }
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final session = await _runtime!.coordinator.loadOrStartSession();
      if (mounted) {
        setState(() {
          _session = session;
          _loading = false;
          _questionGeneration++;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  void dispose() {
    final player = _runtime?.audioPlayer;
    if (player != null) unawaited(player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = AppLocalizations.of(context)!;
    final session = _session;
    final correction = session?.status == QuizSessionStatus.active &&
            session?.currentAnswer?.correct == false
        ? labels.quizCorrectAnswer(session!.currentPrompt!.expectedAnswer)
        : null;
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text(labels.reviewTitle, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      if (!_loading && (_runtime?.coordinator.recoveredSession ?? false))
        Semantics(
          label: labels.quizSessionRecovery,
          liveRegion: true,
          excludeSemantics: true,
          child: Text(labels.quizSessionRecovery,
              key: const ValueKey('quiz-session-recovery')),
        ),
      if (_error) ...[
        Semantics(
          label: labels.quizStorageFailure,
          liveRegion: true,
          excludeSemantics: true,
          child: Text(labels.quizStorageFailure,
              key: const ValueKey('quiz-storage-error')),
        ),
        TextButton(
            onPressed: _busy || _loading ? null : _retry,
            child: Text(labels.quizRetry)),
      ] else if (_loading)
        const Center(child: CircularProgressIndicator())
      else if (session == null)
        Text(labels.quizNoEligibleQuestions, key: const ValueKey('quiz-empty'))
      else if (session.status == QuizSessionStatus.completed) ...[
        Semantics(
          label: labels.quizCompletionSummary(
              session.correctCount, session.prompts.length),
          liveRegion: true,
          excludeSemantics: true,
          child: Text(
              labels.quizCompletionSummary(
                  session.correctCount, session.prompts.length),
              key: const ValueKey('quiz-completion')),
        ),
        const SizedBox(height: 24),
        FilledButton(
            key: const ValueKey('quiz-start-again'),
            onPressed: _busy ? null : _load,
            child: Text(labels.quizStartAgain)),
        const SizedBox(height: 12),
        OutlinedButton(
            key: const ValueKey('quiz-return-to-learning'),
            onPressed: widget.onReturnToLearning ??
                () => Navigator.of(context).maybePop(),
            child: Text(labels.quizReturnToLearning)),
      ] else ...[
        Semantics(
          label: labels.quizProgressAnnouncement(
              session.currentIndex + 1, session.prompts.length),
          liveRegion: true,
          excludeSemantics: true,
          child: Text(
              labels.quizSessionProgress(
                  session.currentIndex + 1, session.prompts.length),
              key: const ValueKey('quiz-progress')),
        ),
        QuestionView(
          key: ValueKey(
              '${session.id}-${session.currentIndex}-$_questionGeneration'),
          prompt: session.currentPrompt!,
          audioPlayer: _runtime!.audioPlayer,
          onSubmit: _submit,
          disabled: _busy || session.currentAnswer != null,
          initialResponse: session.currentAnswer?.response,
        ),
        if (session.currentAnswer != null) ...[
          Semantics(
            label: session.currentAnswer!.correct
                ? labels.quizAnswerCorrect
                : '${labels.quizAnswerIncorrect}\n$correction',
            liveRegion: true,
            excludeSemantics: true,
            child: Container(
              key: const ValueKey('quiz-answer-feedback'),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: session.currentAnswer!.correct
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    session.currentAnswer!.correct
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    color: session.currentAnswer!.correct
                        ? Theme.of(context).colorScheme.onSecondaryContainer
                        : Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.currentAnswer!.correct
                              ? labels.quizAnswerCorrect
                              : labels.quizAnswerIncorrect,
                          style: TextStyle(
                            color: session.currentAnswer!.correct
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                          ),
                        ),
                        if (correction != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            correction,
                            key: const ValueKey('quiz-correct-answer'),
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
              key: const ValueKey('quiz-continue'),
              onPressed: _busy ? null : _continue,
              child: Text(labels.quizContinue)),
        ],
      ],
    ]);
  }
}

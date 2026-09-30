import 'quiz_generator.dart';
import 'quiz_session.dart';

class QuizSessionCoordinator {
  QuizSessionCoordinator({
    required this.store,
    required this.queueFactory,
    required this.newSessionId,
    required this.now,
    required this.contentVersion,
  });

  final QuizSessionStore store;
  final Future<List<QuizPrompt>> Function() queueFactory;
  final String Function() newSessionId;
  final DateTime Function() now;
  final String contentVersion;
  QuizSession? _observedSession;

  Future<QuizSession?> loadOrStartSession() async {
    final existing = await store.loadActiveSession();
    if (existing != null) {
      _observedSession = existing;
      return existing;
    }
    final queue = (await queueFactory()).take(10).toList(growable: false);
    if (queue.isEmpty) {
      _observedSession = null;
      return null;
    }
    final fresh = QuizSession(
      id: newSessionId(),
      contentVersion: contentVersion,
      prompts: queue,
      currentIndex: 0,
      currentQuestionStartedAt: now(),
      currentAnswer: null,
      correctCount: 0,
      answeredCount: 0,
      status: QuizSessionStatus.active,
    );
    await store.saveNewSession(fresh);
    _observedSession = fresh;
    return fresh;
  }

  Future<QuizSession> submitAnswer(String response) async {
    final session = _observedSession;
    if (session == null ||
        session.status != QuizSessionStatus.active ||
        session.currentAnswer != null) {
      throw const QuizSessionConflict(
          'Session missing or question already answered');
    }
    final occurredAt = now();
    final elapsed =
        occurredAt.difference(session.currentQuestionStartedAt).inMilliseconds;
    final updated = await store.submitAnswer(
      sessionId: session.id,
      expectedIndex: session.currentIndex,
      response: response,
      correct: session.currentPrompt!.evaluate(response),
      occurredAt: occurredAt,
      latencyMs: elapsed < 0 ? 0 : elapsed,
    );
    _observedSession = updated;
    return updated;
  }

  Future<QuizSession> continueSession() async {
    final session = _observedSession;
    if (session == null ||
        session.status != QuizSessionStatus.active ||
        session.currentAnswer == null) {
      throw const QuizSessionConflict('No answered question to continue');
    }
    final updated = await store.continueSession(
      sessionId: session.id,
      expectedIndex: session.currentIndex,
    );
    _observedSession = updated;
    return updated;
  }
}

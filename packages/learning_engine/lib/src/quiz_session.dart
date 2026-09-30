import 'quiz_generator.dart';

enum QuizSessionStatus { active, completed }

class QuizSessionConflict implements Exception {
  const QuizSessionConflict(this.message);
  final String message;

  @override
  String toString() => 'QuizSessionConflict: $message';
}

class QuizAnswer {
  QuizAnswer(
      {required this.response,
      required this.correct,
      required this.occurredAt,
      required this.latencyMs}) {
    if (latencyMs < 0) throw const FormatException('Negative answer latency');
  }

  final String response;
  final bool correct;
  final DateTime occurredAt;
  final int latencyMs;

  Map<String, Object?> toJson() => {
        'response': response,
        'correct': correct,
        'occurredAt': occurredAt.toIso8601String(),
        'latencyMs': latencyMs,
      };

  factory QuizAnswer.fromJson(Map<String, dynamic> json) {
    try {
      return QuizAnswer(
        response: json['response'] as String,
        correct: json['correct'] as bool,
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        latencyMs: json['latencyMs'] as int,
      );
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Malformed quiz answer: $error');
    }
  }
}

/// Immutable snapshot of an ordered quiz queue and its current feedback.
class QuizSession {
  QuizSession({
    required this.id,
    required this.contentVersion,
    required List<QuizPrompt> prompts,
    required this.currentIndex,
    required this.currentQuestionStartedAt,
    required this.currentAnswer,
    required this.correctCount,
    required this.answeredCount,
    required this.status,
  }) : prompts = List.unmodifiable(prompts) {
    _validate();
  }

  static const codecVersion = 1;

  final String id;
  final String contentVersion;
  final List<QuizPrompt> prompts;
  final int currentIndex;
  final DateTime currentQuestionStartedAt;
  final QuizAnswer? currentAnswer;
  final int correctCount;
  final int answeredCount;
  final QuizSessionStatus status;

  QuizPrompt? get currentPrompt =>
      status == QuizSessionStatus.active ? prompts[currentIndex] : null;

  void _validate() {
    if (id.trim().isEmpty ||
        contentVersion.trim().isEmpty ||
        prompts.isEmpty ||
        prompts.map((prompt) => prompt.id).toSet().length != prompts.length ||
        prompts
                .map((prompt) => (prompt.itemId, prompt.skill, prompt.type))
                .toSet()
                .length !=
            prompts.length) {
      throw const FormatException('Invalid quiz session identity or queue');
    }
    if (correctCount < 0 ||
        answeredCount < 0 ||
        correctCount > answeredCount ||
        answeredCount > prompts.length) {
      throw const FormatException('Invalid quiz session counts');
    }
    if (status == QuizSessionStatus.active) {
      if (currentIndex < 0 ||
          currentIndex >= prompts.length ||
          answeredCount != currentIndex + (currentAnswer == null ? 0 : 1)) {
        throw const FormatException('Invalid active quiz session cursor');
      }
    } else if (currentIndex != prompts.length ||
        answeredCount != prompts.length ||
        currentAnswer != null) {
      throw const FormatException('Invalid completed quiz session cursor');
    }
  }

  QuizSession copyWith({
    int? currentIndex,
    DateTime? currentQuestionStartedAt,
    QuizAnswer? currentAnswer,
    bool clearAnswer = false,
    int? correctCount,
    int? answeredCount,
    QuizSessionStatus? status,
  }) =>
      QuizSession(
        id: id,
        contentVersion: contentVersion,
        prompts: prompts,
        currentIndex: currentIndex ?? this.currentIndex,
        currentQuestionStartedAt:
            currentQuestionStartedAt ?? this.currentQuestionStartedAt,
        currentAnswer: clearAnswer ? null : currentAnswer ?? this.currentAnswer,
        correctCount: correctCount ?? this.correctCount,
        answeredCount: answeredCount ?? this.answeredCount,
        status: status ?? this.status,
      );

  Map<String, Object?> toJson() => {
        'codecVersion': codecVersion,
        'id': id,
        'contentVersion': contentVersion,
        'prompts': prompts.map((prompt) => prompt.toJson()).toList(),
        'currentIndex': currentIndex,
        'currentQuestionStartedAt': currentQuestionStartedAt.toIso8601String(),
        'currentAnswer': currentAnswer?.toJson(),
        'correctCount': correctCount,
        'answeredCount': answeredCount,
        'status': status.name,
      };

  factory QuizSession.fromJson(Map<String, dynamic> json) {
    if (json['codecVersion'] != codecVersion) {
      throw const FormatException('Unsupported quiz session codec version');
    }
    try {
      final rawPrompts = json['prompts'] as List<dynamic>;
      final rawAnswer = json['currentAnswer'];
      return QuizSession(
        id: json['id'] as String,
        contentVersion: json['contentVersion'] as String,
        prompts: rawPrompts
            .map((raw) => QuizPrompt.fromJson(raw as Map<String, dynamic>))
            .toList(),
        currentIndex: json['currentIndex'] as int,
        currentQuestionStartedAt:
            DateTime.parse(json['currentQuestionStartedAt'] as String),
        currentAnswer: rawAnswer == null
            ? null
            : QuizAnswer.fromJson(rawAnswer as Map<String, dynamic>),
        correctCount: json['correctCount'] as int,
        answeredCount: json['answeredCount'] as int,
        status: QuizSessionStatus.values.byName(json['status'] as String),
      );
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Malformed quiz session: $error');
    }
  }
}

/// Implemented by persistence in Task 3. Writes compare both ID and cursor.
abstract interface class QuizSessionStore {
  Future<QuizSession?> loadActiveSession();
  Future<void> saveNewSession(QuizSession session);
  Future<QuizSession> submitAnswer({
    required String sessionId,
    required int expectedIndex,
    required String response,
    required bool correct,
    required DateTime occurredAt,
    required int latencyMs,
  });
  Future<QuizSession> continueSession({
    required String sessionId,
    required int expectedIndex,
  });
}

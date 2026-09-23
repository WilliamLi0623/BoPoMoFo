import 'ids.dart';
import 'enums.dart';

class LearningEvent {
  EventId eventId;
  UserId userId;
  DeviceId deviceId;
  ItemId itemId;
  Skill skill;
  DateTime occurredAt;
  bool correct;
  int latencyMs;
  int hintCount;
  int retryCount;
  String? response;

  LearningEvent({
    required this.eventId,
    required this.userId,
    required this.deviceId,
    required this.itemId,
    required this.skill,
    required this.occurredAt,
    required this.correct,
    required this.latencyMs,
    required this.hintCount,
    required this.retryCount,
    this.response,
  }) {
    if (eventId.trim().isEmpty) {
      throw ArgumentError.value(eventId, 'eventId', 'must not be empty');
    }
  }

  Map<String, Object?> toMap() => {
        'eventId': eventId,
        'userId': userId,
        'deviceId': deviceId,
        'itemId': itemId,
        'skill': skill.name,
        'occurredAt': occurredAt.toIso8601String(),
        'correct': correct,
        'latencyMs': latencyMs,
        'hintCount': hintCount,
        'retryCount': retryCount,
        'response': response,
      };

  factory LearningEvent.fromMap(Map<String, Object?> map) => LearningEvent(
        eventId: map['eventId']! as String,
        userId: map['userId']! as String,
        deviceId: map['deviceId']! as String,
        itemId: map['itemId']! as String,
        skill: Skill.values.byName(map['skill']! as String),
        occurredAt: DateTime.parse(map['occurredAt']! as String),
        correct: map['correct']! as bool,
        latencyMs: map['latencyMs']! as int,
        hintCount: map['hintCount']! as int,
        retryCount: map['retryCount']! as int,
        response: map['response'] as String?,
      );
}

class ReviewState {
  ItemId itemId;
  Skill skill;
  double difficulty;
  double stability;
  DateTime? lastReviewAt;
  DateTime dueAt;
  int reps;

  ReviewState({
    required this.itemId,
    required this.skill,
    required this.difficulty,
    required this.stability,
    this.lastReviewAt,
    required this.dueAt,
    required this.reps,
  });
}

class ReviewAttempt {
  final ItemId itemId;
  final Skill skill;
  final bool correct;
  final DateTime occurredAt;
  final int latencyMs;
  final String? response;

  const ReviewAttempt({
    required this.itemId,
    required this.skill,
    required this.correct,
    required this.occurredAt,
    this.latencyMs = 0,
    this.response,
  });
}

class DashboardSnapshot {
  final int dueCount;
  final int masteredCount;

  const DashboardSnapshot({this.dueCount = 0, this.masteredCount = 0});
}

class Symbol {
  final String id;
  final String glyph;
  final String category;
  final String? pinyin;
  final String keyboardKey;

  const Symbol({
    required this.id,
    required this.glyph,
    required this.category,
    this.pinyin,
    required this.keyboardKey,
  });
}

class Syllable {
  final String id;
  final String zhuyin;
  final String pinyin;
  final String? initial;
  final String? medial;
  final String? finalSymbol;
  final int tone;

  const Syllable({
    required this.id,
    required this.zhuyin,
    required this.pinyin,
    this.initial,
    this.medial,
    this.finalSymbol,
    required this.tone,
  });
}

import 'package:test/test.dart';

import 'package:domain/domain.dart';

void main() {
  test('LearningEvent round-trips with timestamps and skill', () {
    final occurredAt = DateTime.utc(2026, 9, 22, 8, 30, 12, 345);
    final event = LearningEvent(
      eventId: 'event-1',
      userId: 'user-1',
      deviceId: 'device-1',
      itemId: 'item-1',
      skill: Skill.production,
      occurredAt: occurredAt,
      correct: true,
      latencyMs: 812,
      hintCount: 1,
      retryCount: 0,
      response: 'ㄇㄚ',
    );

    final restored = LearningEvent.fromMap(event.toMap());

    expect(restored.eventId, event.eventId);
    expect(restored.skill, Skill.production);
    expect(restored.occurredAt, occurredAt);
    expect(restored.toMap(), event.toMap());
  });

  test('LearningEvent rejects an empty event id', () {
    expect(
      () => LearningEvent(
        eventId: '',
        userId: 'user-1',
        deviceId: 'device-1',
        itemId: 'item-1',
        skill: Skill.recognition,
        occurredAt: DateTime.utc(2026),
        correct: false,
        latencyMs: 0,
        hintCount: 0,
        retryCount: 0,
      ),
      throwsArgumentError,
    );
  });
}

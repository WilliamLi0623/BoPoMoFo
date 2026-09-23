import 'dart:convert';

import 'package:test/test.dart';

import 'package:domain/domain.dart';
import 'package:persistence/persistence.dart';

void main() {
  test('export round-trips event fields and confusion projections', () async {
    final source = await LocalLearningRepository.inMemory();
    await source.appendEvent(LearningEvent(
      eventId: 'e1', userId: 'u', deviceId: 'd', itemId: 'ㄅ',
      skill: Skill.keyboard, occurredAt: DateTime.utc(2026, 9, 22),
      correct: false, latencyMs: 812, hintCount: 1, retryCount: 2,
      response: 'ㄆ',
    ));
    await source.appendEvent(LearningEvent(
      eventId: 'e2', userId: 'u', deviceId: 'd', itemId: 'ㄅ',
      skill: Skill.keyboard, occurredAt: DateTime.utc(2026, 9, 22, 0, 1),
      correct: false, latencyMs: 813, hintCount: 0, retryCount: 1,
      response: 'ㄆ',
    ));
    await source.markUploaded(['e1', 'e2'], DateTime.utc(2026, 9, 23));
    final json = await source.exportLearningData();
    final exported = jsonDecode(json) as Map<String, dynamic>;
    expect(exported['schemaVersion'], 1);
    expect(exported['contentVersion'], currentContentVersion);
    expect(exported['algorithmVersion'], currentAlgorithmVersion);
    expect(exported['device'], containsPair('deviceId', 'local-device'));
    expect(exported['device'], isNot(containsPair('userId', anything)));
    expect(exported['events'], hasLength(2));

    final restored = await LocalLearningRepository.inMemory();
    await restored.importLearningData(json);
    await restored.importLearningData(json);

    final snapshot = await restored.replayLocal();
    expect(snapshot.reviewStates.single.reps, 2);
    expect(snapshot.confusionTargets.single.key, 'ㄅ->ㄆ');
    expect(
      (await restored.events.all()).firstWhere((event) => event.eventId == 'e1').latencyMs,
      812,
    );
    expect(
      (await restored.events.all()).firstWhere((event) => event.eventId == 'e1').response,
      'ㄆ',
    );
    // Upload state is outbox metadata, not part of the event-transfer
    // contract; imported events are therefore pending on the new device.
    expect((await restored.pendingEvents()).length, 2);
    await source.close();
    await restored.close();
  });

  test('rejects unsupported content versions before local mutation', () async {
    final repository = await LocalLearningRepository.inMemory();
    await repository.appendEvent(LearningEvent(
      eventId: 'existing', userId: 'u', deviceId: 'd', itemId: 'ㄅ',
      skill: Skill.keyboard, occurredAt: DateTime.utc(2026, 9, 22),
      correct: true, latencyMs: 1, hintCount: 0, retryCount: 0,
    ));
    const json =
        '{"schemaVersion":1,"contentVersion":"content-unsupported","algorithmVersion":"fsrs-lite-1","device":{"deviceId":"d"},"events":[]}';

    await expectLater(
      repository.importLearningData(json),
      throwsA(isA<LearningDataValidationException>()),
    );
    expect((await repository.events.all()).map((event) => event.eventId), ['existing']);
    await repository.close();
  });

  test('rejects unsupported algorithm versions before local mutation', () async {
    final repository = await LocalLearningRepository.inMemory();
    await repository.appendEvent(LearningEvent(
      eventId: 'existing', userId: 'u', deviceId: 'd', itemId: 'ㄅ',
      skill: Skill.keyboard, occurredAt: DateTime.utc(2026, 9, 22),
      correct: true, latencyMs: 1, hintCount: 0, retryCount: 0,
    ));
    const json =
        '{"schemaVersion":1,"contentVersion":"content-1","algorithmVersion":"fsrs-unsupported","device":{"deviceId":"d"},"events":[]}';

    await expectLater(
      repository.importLearningData(json),
      throwsA(isA<LearningDataValidationException>()),
    );
    expect((await repository.events.all()).map((event) => event.eventId), ['existing']);
    await repository.close();
  });

  test('rejects invalid envelope versions and missing contract metadata', () async {
    final invalidEnvelopes = [
      '{"schemaVersion":99,"contentVersion":"content-1","algorithmVersion":"fsrs-lite-1","device":{"deviceId":"d"},"events":[]}',
      '{"schemaVersion":1,"contentVersion":"","algorithmVersion":"fsrs-lite-1","device":{"deviceId":"d"},"events":[]}',
      '{"schemaVersion":1,"contentVersion":"content-1","algorithmVersion":"","device":{"deviceId":"d"},"events":[]}',
      '{"schemaVersion":1,"contentVersion":"content-1","algorithmVersion":"fsrs-lite-1","device":{},"events":[]}',
    ];

    for (final json in invalidEnvelopes) {
      expect(
        () => LearningDataEnvelope.decode(json),
        throwsA(isA<LearningDataValidationException>()),
      );
    }
  });

  test('invalid import leaves the current learning state unchanged', () async {
    final repository = await LocalLearningRepository.inMemory();
    await repository.recordReview(ReviewAttempt(
      itemId: 'ㄅ',
      skill: Skill.keyboard,
      correct: true,
      occurredAt: DateTime.utc(2026, 9, 23),
    ));
    final before = await repository.snapshot();

    await expectLater(repository.importLearningData('{not-json'), throwsA(anything));

    final after = await repository.snapshot();
    expect(after.reviewStates.length, before.reviewStates.length);
    expect(after.reviewStates.single.itemId, before.reviewStates.single.itemId);
    await repository.close();
  });
}

import 'dart:io';

import 'package:test/test.dart';

import 'package:domain/domain.dart';
import 'package:srs/srs.dart';
import 'package:persistence/persistence.dart';

class FailingScheduler implements Scheduler {
  @override
  ReviewState schedule(ReviewState state, ReviewRating rating, DateTime now) {
    throw StateError('injected projection failure');
  }
}

LearningEvent event(String id, {bool correct = true, String? response}) => LearningEvent(
      eventId: id,
      userId: 'user-1',
      deviceId: 'device-1',
      itemId: 'ㄓ',
      skill: Skill.recognition,
      occurredAt: DateTime.utc(2026, 9, 22, 12),
      correct: correct,
      latencyMs: 100,
      hintCount: 0,
      retryCount: 0,
      response: response,
    );

void main() {
  test('unique event IDs are idempotent and upload acknowledgement keeps history', () async {
    final repository = await LocalLearningRepository.inMemory();
    await repository.appendEvent(event('e1'));
    await repository.appendEvent(event('e1', correct: false));

    expect((await repository.pendingEvents()).map((e) => e.eventId), ['e1']);
    await repository.markUploaded(['e1'], DateTime.utc(2026, 9, 23));
    expect(await repository.pendingEvents(), isEmpty);
    expect((await repository.replayLocal()).reviewStates.single.reps, 1);
    await repository.close();
  });

  test('review transaction updates projection and confusion atomically', () async {
    final repository = await LocalLearningRepository.inMemory();
    await repository.appendEvent(event('e1', correct: false, response: 'ㄔ'));
    await repository.appendEvent(event('e2', correct: false, response: 'ㄔ'));

    final snapshot = await repository.replayLocal();
    expect(snapshot.reviewStates.single.reps, 2);
    expect(snapshot.confusionTargets.single.key, 'ㄓ->ㄔ');
    await repository.close();
  });

  test('reopening the SQLite database recovers events and projections', () async {
    final directory = await Directory.systemTemp.createTemp('bopomofo-persistence-');
    final path = '${directory.path}${Platform.pathSeparator}learning.sqlite';
    final first = LocalLearningRepository(
      database: LocalDatabase.atPath(path),
    );
    await first.database.open();
    await first.appendEvent(event('restart-1'));
    await first.close();

    final second = LocalLearningRepository(
      database: LocalDatabase.atPath(path),
    );
    await second.database.open();
    expect((await second.replayLocal()).reviewStates.single.reps, 1);
    await second.close();
    await directory.delete(recursive: true);
  });

  test('failed review rolls back event, outbox, and projections together', () async {
    final database = LocalDatabase.inMemory();
    await database.open();
    final repository = LocalLearningRepository(
      database: database,
      scheduler: FailingScheduler(),
    );

    await expectLater(repository.appendEvent(event('rollback-1')), throwsStateError);
    expect(await repository.events.all(), isEmpty);
    expect(await repository.pendingEvents(), isEmpty);
    expect((await repository.replayLocal()).reviewStates, isEmpty);
    await repository.close();
  });

  test('applies the v1 to v2 additive migration instead of only bumping metadata', () async {
    final database = LocalDatabase.inMemory();
    await database.execute('''
      CREATE TABLE schema_info (
        singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
        version INTEGER NOT NULL
      )
    ''');
    await database.execute(
      'INSERT INTO schema_info (singleton, version) VALUES (1, 1)',
    );
    await database.execute('''
      CREATE TABLE device_identity (
        singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
        device_id TEXT NOT NULL,
        platform TEXT NOT NULL,
        app_version TEXT NOT NULL
      )
    ''');

    await database.open();
    final columns = await database.select('PRAGMA table_info(device_identity)');
    expect(columns.map((row) => row['name']), contains('next_event_sequence'));
    expect(
      (await database.select('SELECT version FROM schema_info')).single['version'],
      2,
    );
    await database.close();
  });

  test('generated event IDs remain unique after repository restart', () async {
    final directory = await Directory.systemTemp.createTemp('bopomofo-id-');
    final path = '${directory.path}${Platform.pathSeparator}learning.sqlite';
    final occurredAt = DateTime.utc(2026, 9, 22, 12);
    final attempt = ReviewAttempt(
      itemId: 'ㄓ',
      skill: Skill.recognition,
      correct: true,
      occurredAt: occurredAt,
    );

    final first = LocalLearningRepository(database: LocalDatabase.atPath(path));
    await first.database.open();
    await first.recordReview(attempt);
    await first.close();

    final second = LocalLearningRepository(database: LocalDatabase.atPath(path));
    await second.database.open();
    await second.recordReview(attempt);
    final ids = (await second.events.all()).map((event) => event.eventId).toSet();

    expect(ids, hasLength(2));
    await second.close();
    await directory.delete(recursive: true);
  });
}

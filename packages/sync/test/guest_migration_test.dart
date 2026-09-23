import 'package:domain/domain.dart';
import 'package:persistence/persistence.dart';
import 'package:sync/sync.dart';
import 'package:test/test.dart';

LearningEvent event(String id, {String userId = 'guest'}) => LearningEvent(
      eventId: id,
      userId: userId,
      deviceId: 'device-a',
      itemId: 'ㄓ',
      skill: Skill.recognition,
      occurredAt: DateTime.utc(2026, 9, 22, 12),
      correct: true,
      latencyMs: 100,
      hintCount: 0,
      retryCount: 0,
    );

void main() {
  test('guest migration merges local and remote events without deleting local history', () {
    final result = GuestMigration.merge(
      local: [event('local-1'), event('same')],
      remote: [event('remote-1', userId: 'user-1'), event('same', userId: 'user-1')],
      authenticatedUserId: 'user-1',
    );

    expect(result.events.map((event) => event.eventId), ['local-1', 'remote-1', 'same']);
    expect(result.events.every((event) => event.userId == 'user-1'), isTrue);
    expect(result.events, hasLength(3));
  });

  test('migration uploads authenticated copies and keeps local history', () async {
    final repository = await LocalLearningRepository.inMemory();
    await repository.appendEvent(event('local-1'));
    final uploaded = <LearningEvent>[];
    final transport = _MigrationTransport(uploaded);

    await GuestMigration.migrate(
      repository: repository,
      transport: transport,
      authenticatedUserId: 'user-1',
    );

    expect(uploaded.single.userId, 'user-1');
    expect((await repository.events.all()).map((event) => event.eventId), ['local-1']);
    await repository.close();
  });

  test('migration merges remote events and does not re-enqueue acknowledged rows', () async {
    final repository = await LocalLearningRepository.inMemory();
    await repository.appendEvent(event('local-1'));
    final uploaded = <LearningEvent>[];
    final transport = _MigrationTransport(uploaded)
      ..remote.add(event('remote-1', userId: 'user-1'));

    await GuestMigration.migrate(
      repository: repository,
      transport: transport,
      authenticatedUserId: 'user-1',
    );

    expect(uploaded.map((event) => event.eventId), ['local-1', 'remote-1']);
    expect((await repository.events.all()).map((event) => event.eventId),
        ['local-1', 'remote-1']);
    expect(await repository.pendingEvents(), isEmpty);
    await repository.close();
  });
}

class _MigrationTransport implements SyncTransport {
  _MigrationTransport(this.uploaded);

  final List<LearningEvent> uploaded;
  final List<LearningEvent> remote = [];

  @override
  Future<UploadResult> upload(List<LearningEvent> events) async {
    uploaded.addAll(events);
    return UploadResult(acknowledgedIds: events.map((event) => event.eventId));
  }

  @override
  Future<DownloadResult> download({required SyncCursor cursor}) async =>
      DownloadResult(events: remote, nextCursor: cursor);
}

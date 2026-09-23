import 'package:domain/domain.dart';
import 'package:persistence/persistence.dart';
import 'package:srs/srs.dart';
import 'package:sync/sync.dart';
import 'package:test/test.dart';

LearningEvent event(String id, {String deviceId = 'device-a', String itemId = 'ㄓ'}) => LearningEvent(
      eventId: id,
      userId: 'user-1',
      deviceId: deviceId,
      itemId: itemId,
      skill: Skill.recognition,
      occurredAt: DateTime.utc(2026, 9, 22, 12),
      correct: true,
      latencyMs: 100,
      hintCount: 0,
      retryCount: 0,
    );

class FakeTransport implements SyncTransport {
  final List<LearningEvent> uploaded = [];
  List<LearningEvent> remote = [];
  SyncCursor nextCursor = const SyncCursor('cursor-1');
  bool failUpload = false;
  bool failDownload = false;
  bool failMerge = false;
  int uploadCalls = 0;
  final List<SyncCursor> requestedCursors = [];

  @override
  Future<UploadResult> upload(List<LearningEvent> events) async {
    uploadCalls++;
    if (failUpload) throw const SyncTransportUnavailable('offline');
    uploaded.addAll(events);
    return UploadResult(acknowledgedIds: events.map((event) => event.eventId));
  }

  @override
  Future<DownloadResult> download({required SyncCursor cursor}) async {
    requestedCursors.add(cursor);
    if (failDownload) throw const SyncTransportUnavailable('offline');
    if (failMerge) {
      return DownloadResult(
        events: [event('bad', deviceId: 'device-b')],
        nextCursor: SyncCursor.composite(
          DateTime.utc(2026, 9, 22, 12),
          'bad',
        ),
      );
    }
    return DownloadResult(events: remote, nextCursor: nextCursor);
  }
}

void main() {
  test('offline failure retains pending events and local replay', () async {
    final repository = await LocalLearningRepository.inMemory();
    await repository.appendEvent(event('e1'));
    final transport = FakeTransport()..failUpload = true;
    final service = LocalSyncService(repository: repository, transport: transport);

    final result = await service.syncNow();

    expect(result.status, SyncStatus.offline);
    expect((await repository.pendingEvents()).map((e) => e.eventId), ['e1']);
    expect((await repository.replayLocal()).reviewStates, isNotEmpty);
    expect(result.message, contains('saved locally'));
    await repository.close();
  });

  test('retry uploads deterministic pending events once and is idempotent', () async {
    final repository = await LocalLearningRepository.inMemory();
    await repository.appendEvent(event('e2'));
    await repository.appendEvent(event('e1'));
    final transport = FakeTransport();
    final service = LocalSyncService(repository: repository, transport: transport);

    await service.syncNow();
    await service.syncNow();

    expect(transport.uploaded.map((e) => e.eventId), ['e1', 'e2']);
    expect(transport.uploadCalls, 1);
    expect(await repository.pendingEvents(), isEmpty);
    await repository.close();
  });

  test('download cursor advances only after merge and replay succeed', () async {
    final repository = await LocalLearningRepository.inMemory();
    final transport = FakeTransport()
      ..remote = [event('remote-1', deviceId: 'device-b')]
      ..nextCursor = SyncCursor.composite(
        DateTime.utc(2026, 9, 22, 12),
        'remote-1',
      );
    final service = LocalSyncService(repository: repository, transport: transport);

    await service.syncNow();

    expect(
      await service.readCursor(),
      SyncCursor.composite(DateTime.utc(2026, 9, 22, 12), 'remote-1'),
    );
    expect((await repository.events.all()).map((e) => e.eventId), ['remote-1']);
    await repository.close();
  });

  test('same-timestamp remote events after the cursor are not skipped', () async {
    final repository = await LocalLearningRepository.inMemory();
    final transport = FakeTransport()
      ..remote = [
        event('event-a', deviceId: 'device-b'),
        event('event-b', deviceId: 'device-b'),
      ]
      ..nextCursor = SyncCursor.composite(
        DateTime.utc(2026, 9, 22, 12),
        'event-a',
      );
    final service = LocalSyncService(repository: repository, transport: transport);

    await service.syncNow();
    transport.remote = [event('event-b', deviceId: 'device-b')];
    await service.syncNow();

    expect(transport.requestedCursors[1],
        SyncCursor.composite(DateTime.utc(2026, 9, 22, 12), 'event-a'));
    expect((await repository.events.all()).map((event) => event.eventId), [
      'event-a',
      'event-b',
    ]);
    await repository.close();
  });

  test('download failure keeps the previous cursor and upload pending', () async {
    final repository = await LocalLearningRepository.inMemory();
    await repository.appendEvent(event('local-1'));
    final transport = FakeTransport()..failDownload = true;
    final service = LocalSyncService(repository: repository, transport: transport);

    final result = await service.syncNow();

    expect(result.status, SyncStatus.offline);
    expect(await service.readCursor(), SyncCursor.initial);
    expect((await repository.pendingEvents()).map((e) => e.eventId), ['local-1']);
    await repository.close();
  });

  test('duplicate remote events are ignored and A/B/C merge is deterministic', () async {
    final repository = await LocalLearningRepository.inMemory();
    await repository.appendEvent(event('b', deviceId: 'device-b'));
    final transport = FakeTransport()
      ..remote = [
        event('a', deviceId: 'device-a'),
        event('b', deviceId: 'device-b'),
        event('c', deviceId: 'device-c'),
      ];
    final service = LocalSyncService(repository: repository, transport: transport);

    await service.syncNow();

    expect((await repository.events.all()).map((e) => e.eventId), ['a', 'b', 'c']);
    await repository.close();
  });

  test('replay failure reports error and retains cursor and pending events', () async {
    final database = LocalDatabase.inMemory();
    await database.open();
    final repository = LocalLearningRepository(
      database: database,
      scheduler: _FailingScheduler(),
    );
    await repository.appendEvent(event('local-1'));
    final transport = FakeTransport()
      ..remote = [event('remote-1', deviceId: 'device-b', itemId: 'bad')];
    final service = LocalSyncService(repository: repository, transport: transport);

    final result = await service.syncNow();

    expect(result.status, SyncStatus.error);
    expect(await service.readCursor(), SyncCursor.initial);
    expect((await repository.events.all()).map((event) => event.eventId), ['local-1']);
    expect((await repository.pendingEvents()).map((event) => event.eventId), ['local-1']);
    expect(result.message, contains('saved locally'));
    await repository.close();
  });
}

class _FailingScheduler implements Scheduler {
  @override
  ReviewState schedule(ReviewState state, ReviewRating rating, DateTime now) {
    if (state.itemId == 'bad') throw StateError('merge failed');
    return state;
  }
}

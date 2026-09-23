import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:learning_engine/learning_engine.dart' show LearningSnapshot;
import 'package:persistence/persistence.dart';
import 'package:sync/sync.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('two devices merge A/B/C once and replay the same projection', () async {
    final deviceOne = await LocalLearningRepository.inMemory(
      userId: 'user-1',
      deviceId: 'device-one',
    );
    final deviceTwo = await LocalLearningRepository.inMemory(
      userId: 'user-1',
      deviceId: 'device-two',
    );
    final cloud = _InMemoryTransport();
    final syncOne = LocalSyncService(repository: deviceOne, transport: cloud);
    final syncTwo = LocalSyncService(repository: deviceTwo, transport: cloud);

    try {
      final eventA = _event('A', DateTime.utc(2026, 9, 22, 12), true);
      await deviceOne.appendEvent(eventA);
      await deviceOne
          .appendEvent(_event('B', DateTime.utc(2026, 9, 22, 12, 1), false));
      await syncOne.syncNow();

      await deviceTwo.appendEvent(eventA);
      await deviceTwo
          .appendEvent(_event('C', DateTime.utc(2026, 9, 22, 12, 2), true));
      await syncTwo.syncNow();
      await syncOne.syncNow();

      for (final repository in [deviceOne, deviceTwo]) {
        final events = await repository.events.all();
        expect(events.map((event) => event.eventId), ['A', 'B', 'C']);
        expect(events.where((event) => event.eventId == 'A'), hasLength(1));
      }

      final firstProjection = _projection(await deviceOne.snapshot());
      final secondProjection = _projection(await deviceTwo.snapshot());
      expect(firstProjection, secondProjection);
      expect(firstProjection, isNotEmpty);
    } finally {
      await syncOne.dispose();
      await syncTwo.dispose();
      await deviceOne.close();
      await deviceTwo.close();
    }
  });
}

LearningEvent _event(String id, DateTime at, bool correct) => LearningEvent(
      eventId: id,
      userId: 'user-1',
      deviceId: 'device-${id.toLowerCase()}',
      itemId: 'ㄅ',
      skill: Skill.recognition,
      occurredAt: at,
      correct: correct,
      latencyMs: 250,
      hintCount: 0,
      retryCount: 0,
    );

List<String> _projection(LearningSnapshot snapshot) => snapshot.reviewStates
    .map((state) =>
        '${state.itemId}|${state.skill.name}|${state.difficulty}|${state.stability}|${state.reps}|${state.dueAt.toIso8601String()}')
    .toList()
  ..sort();

class _InMemoryTransport implements SyncTransport {
  final Map<String, LearningEvent> _events = {};

  @override
  Future<UploadResult> upload(List<LearningEvent> events) async {
    for (final event in events) {
      _events.putIfAbsent(event.eventId, () => event);
    }
    return UploadResult(acknowledgedIds: events.map((event) => event.eventId));
  }

  @override
  Future<DownloadResult> download({required SyncCursor cursor}) async {
    final events = _events.values.toList()
      ..sort((left, right) {
        final byTime = left.occurredAt.compareTo(right.occurredAt);
        return byTime == 0 ? left.eventId.compareTo(right.eventId) : byTime;
      });
    final afterCursor = cursor.occurredAt == null
        ? events
        : events.where((event) {
            final byTime = event.occurredAt.compareTo(cursor.occurredAt!);
            return byTime > 0 ||
                (byTime == 0 &&
                    event.eventId.compareTo(cursor.eventId ?? '') > 0);
          }).toList();
    final nextCursor = afterCursor.isEmpty
        ? cursor
        : SyncCursor.composite(
            afterCursor.last.occurredAt,
            afterCursor.last.eventId,
          );
    return DownloadResult(events: afterCursor, nextCursor: nextCursor);
  }
}

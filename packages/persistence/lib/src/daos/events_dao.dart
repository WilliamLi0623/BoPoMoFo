import 'package:domain/domain.dart';

import '../database.dart';

class EventsDao {
  final LocalDatabase database;

  const EventsDao(this.database);

  Future<LearningEvent?> find(EventId eventId) async {
    final rows = await database.select(
      'SELECT * FROM learning_events WHERE event_id = ?',
      [eventId],
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<void> insert(LearningEvent event) async {
    await database.execute('''
      INSERT OR IGNORE INTO learning_events
      (event_id, user_id, device_id, item_id, skill, occurred_at, correct,
       latency_ms, hint_count, retry_count, response, uploaded_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
    ''', [
      event.eventId,
      event.userId,
      event.deviceId,
      event.itemId,
      event.skill.name,
      event.occurredAt.toUtc().toIso8601String(),
      event.correct ? 1 : 0,
      event.latencyMs,
      event.hintCount,
      event.retryCount,
      event.response,
    ]);
    await database.execute(
      'INSERT OR IGNORE INTO outbox_metadata (event_id, uploaded_at) VALUES (?, NULL)',
      [event.eventId],
    );
  }

  Future<List<LearningEvent>> all() async {
    final rows = await database.select(
      'SELECT * FROM learning_events ORDER BY occurred_at ASC, event_id ASC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<List<LearningEvent>> pending({int limit = 100}) async {
    if (limit <= 0) return const [];
    final rows = await database.select('''
      SELECT e.* FROM learning_events e
      JOIN outbox_metadata o ON o.event_id = e.event_id
      WHERE o.uploaded_at IS NULL
      ORDER BY e.occurred_at ASC, e.event_id ASC
      LIMIT ?
    ''', [limit]);
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<void> markUploaded(Iterable<EventId> ids, DateTime uploadedAt) async {
    final timestamp = uploadedAt.toUtc().toIso8601String();
    for (final id in ids.toSet()) {
      await database.execute(
        'UPDATE outbox_metadata SET uploaded_at = ? WHERE event_id = ?',
        [timestamp, id],
      );
      await database.execute(
        'UPDATE learning_events SET uploaded_at = ? WHERE event_id = ?',
        [timestamp, id],
      );
    }
  }

  static LearningEvent _fromRow(Map<String, Object?> row) => LearningEvent(
        eventId: row['event_id']! as String,
        userId: row['user_id']! as String,
        deviceId: row['device_id']! as String,
        itemId: row['item_id']! as String,
        skill: Skill.values.byName(row['skill']! as String),
        occurredAt: DateTime.parse(row['occurred_at']! as String),
        correct: (row['correct']! as num) != 0,
        latencyMs: row['latency_ms']! as int,
        hintCount: row['hint_count']! as int,
        retryCount: row['retry_count']! as int,
        response: row['response'] as String?,
      );
}

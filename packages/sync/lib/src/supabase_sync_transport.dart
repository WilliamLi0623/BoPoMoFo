import 'package:domain/domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_state.dart';
import 'sync_service.dart';

class SupabaseSyncTransport implements SyncTransport {
  SupabaseSyncTransport(this.client);

  final SupabaseClient client;

  @override
  Future<UploadResult> upload(List<LearningEvent> events) async {
    if (events.isEmpty) return UploadResult(acknowledgedIds: const []);
    try {
      await client.from('learning_events').upsert(
            events.map(_toRow).toList(growable: false),
            onConflict: 'event_id',
            ignoreDuplicates: true,
          );
    } catch (error) {
      throw SyncTransportUnavailable('$error');
    }
    return UploadResult(acknowledgedIds: events.map((event) => event.eventId));
  }

  @override
  Future<DownloadResult> download({required SyncCursor cursor}) async {
    try {
      var query = client.from('learning_events').select();
      if (cursor.occurredAt != null && cursor.eventId != null) {
        final timestamp = cursor.occurredAt!.toIso8601String();
        query = query.or(
          'occurred_at.gt.$timestamp,and(occurred_at.eq.$timestamp,event_id.gt.${cursor.eventId})',
        );
      } else if (cursor.occurredAt != null) {
        query = query.gt('occurred_at', cursor.occurredAt!.toIso8601String());
      }
      final rows = await query.order('occurred_at').order('event_id');
      final events = (rows as List)
          .map((row) => LearningEvent.fromMap(_fromRow(Map<String, dynamic>.from(row as Map))))
          .toList(growable: false);
      final next = events.isEmpty
          ? cursor
          : SyncCursor.composite(events.last.occurredAt, events.last.eventId);
      return DownloadResult(events: events, nextCursor: next);
    } catch (error) {
      throw SyncTransportUnavailable('$error');
    }
  }

  static Map<String, dynamic> _toRow(LearningEvent event) => {
        'event_id': event.eventId,
        'user_id': event.userId,
        'device_id': event.deviceId,
        'item_id': event.itemId,
        'skill': event.skill.name,
        'occurred_at': event.occurredAt.toUtc().toIso8601String(),
        'correct': event.correct,
        'latency_ms': event.latencyMs,
        'hint_count': event.hintCount,
        'retry_count': event.retryCount,
        'response': event.response,
      };

  static Map<String, Object?> _fromRow(Map<String, dynamic> row) => {
        'eventId': row['event_id'],
        'userId': row['user_id'],
        'deviceId': row['device_id'],
        'itemId': row['item_id'],
        'skill': row['skill'],
        'occurredAt': row['occurred_at'],
        'correct': row['correct'],
        'latencyMs': row['latency_ms'],
        'hintCount': row['hint_count'],
        'retryCount': row['retry_count'],
        'response': row['response'],
      };
}

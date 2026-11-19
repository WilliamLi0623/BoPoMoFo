import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:http/http.dart' show ClientException;
import 'package:persistence/persistence.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'sync_state.dart';
import 'sync_service.dart';

class SupabaseSyncTransport implements SyncTransport {
  SupabaseSyncTransport._(this._client, this._userId, this._installation);

  static const cursorKey = 'supabase.events.uploaded.v1';
  static const _bindingKey = 'sync.cloudBinding';
  static const _legacyDevice = 'local-device';
  static const _pageSize = 250;
  static const _requestTimeout = Duration(seconds: 20);
  static const _downloadOverlap = Duration(minutes: 2);

  final SupabaseClient _client;
  final String _userId;
  final String _installation;

  /// The current app has one local learning profile. Its first manual sync
  /// binds that profile to the selected cloud account.
  static Future<SupabaseSyncTransport?> forRepository(
    SupabaseClient client,
    LocalLearningRepository repository,
  ) async {
    final userId = client.auth.currentSession?.user.id;
    if (userId == null) return null;
    final installation = await repository.database.transaction((tx) async {
      final rows = await tx.select(
        'SELECT value FROM settings WHERE key = ?',
        [_bindingKey],
      );
      if (client.auth.currentSession?.user.id != userId) {
        throw const SyncAccountMismatch();
      }
      if (rows.isNotEmpty) {
        final binding = jsonDecode(rows.single['value']! as String) as Map;
        if (binding['userId'] != userId) throw const SyncAccountMismatch();
        return binding['installation'] as String;
      }
      final id = const Uuid().v4();
      await tx.execute(
        'INSERT INTO settings (key, value) VALUES (?, ?)',
        [
          _bindingKey,
          jsonEncode({'userId': userId, 'installation': id})
        ],
      );
      return id;
    });
    return SupabaseSyncTransport._(client, userId, installation);
  }

  @override
  Future<UploadResult> upload(List<LearningEvent> events) async {
    if (events.isEmpty) return UploadResult(acknowledgedIds: const []);
    return _request(() async {
      final rows = {for (final event in events) _wireId(event): event};
      await _client
          .from('learning_events')
          .upsert(
            rows.entries
                .map((entry) => _toRow(entry.key, entry.value))
                .toList(),
            onConflict: 'event_id',
            ignoreDuplicates: true,
          )
          .timeout(_requestTimeout);
      _checkSession();
      // An ignored conflict does not prove the event is owned by this account.
      // Only mark it uploaded after it is visible under the same owner.
      final stored = await _client
          .from('learning_events')
          .select('event_id')
          .eq('user_id', _userId)
          .inFilter('event_id', rows.keys.toList())
          .timeout(_requestTimeout);
      return UploadResult(
        acknowledgedIds: stored.map((row) => rows[row['event_id']]!.eventId),
      );
    });
  }

  @override
  Future<DownloadResult> download({required SyncCursor cursor}) async {
    return _request(() async {
      final events = <LearningEvent>[];
      var page = SyncCursor.initial;
      var next = cursor;
      while (true) {
        _checkSession();
        var query =
            _client.from('learning_events').select().eq('user_id', _userId);
        final uploadedAt = page.occurredAt?.toIso8601String();
        if (uploadedAt != null && page.eventId != null) {
          final timestamp = jsonEncode(uploadedAt);
          final eventId = jsonEncode(page.eventId);
          query = query.or(
            'uploaded_at.gt.$timestamp,and(uploaded_at.eq.$timestamp,event_id.gt.$eventId)',
          );
        } else if (cursor.occurredAt case final previous?) {
          // A transaction can become visible after our previous read. Revisit
          // the recent overlap; the local event primary key deduplicates it.
          query = query.gte('uploaded_at',
              previous.subtract(_downloadOverlap).toIso8601String());
        }
        final rows = await query
            .order('uploaded_at')
            .order('event_id')
            .limit(_pageSize)
            .timeout(_requestTimeout);
        if (rows.isEmpty) break;
        events.addAll(rows.map(_fromRow));
        final last = rows.last;
        // Use server arrival time so a review made offline last week can still
        // be pulled after a newer review has already been synced.
        final checkpoint = SyncCursor.composite(
          DateTime.parse(last['uploaded_at'] as String),
          last['event_id'] as String,
        );
        if (checkpoint == page) {
          throw StateError('Sync cursor did not advance.');
        }
        page = checkpoint;
        if (cursor.occurredAt == null ||
            !checkpoint.occurredAt!.isBefore(cursor.occurredAt!)) {
          next = checkpoint;
        }
      }
      return DownloadResult(events: events, nextCursor: next);
    });
  }

  void _checkSession() {
    if (_client.auth.currentSession?.user.id != _userId) {
      throw const SyncAccountMismatch();
    }
  }

  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      _checkSession();
      final result = await action();
      _checkSession();
      return result;
    } on SocketException {
      throw const SyncTransportUnavailable('Network unavailable.');
    } on ClientException {
      throw const SyncTransportUnavailable('Network request failed.');
    } on TimeoutException {
      throw const SyncTransportUnavailable('Network request timed out.');
    }
  }

  String _wireId(LearningEvent event) {
    final prefix = 'bpm.$_userId.';
    if (event.deviceId != _legacyDevice && event.eventId.startsWith(prefix)) {
      return event.eventId;
    }
    final encoded = base64Url.encode(utf8.encode(event.eventId));
    return event.deviceId == _legacyDevice
        ? '$prefix$_installation.$encoded'
        : '$prefix$encoded';
  }

  Map<String, dynamic> _toRow(String id, LearningEvent event) => {
        'event_id': id,
        'user_id': _userId,
        'device_id':
            event.deviceId == _legacyDevice ? _installation : event.deviceId,
        'item_id': event.itemId,
        'skill': event.skill.name,
        'occurred_at': event.occurredAt.toUtc().toIso8601String(),
        'correct': event.correct,
        'latency_ms': event.latencyMs,
        'hint_count': event.hintCount,
        'retry_count': event.retryCount,
        'response': event.response,
      };

  LearningEvent _fromRow(Map<String, dynamic> row) {
    final wireId = row['event_id'] as String;
    final prefix = 'bpm.$_userId.';
    var localId = wireId;
    var deviceId = row['device_id'] as String;
    if (wireId.startsWith(prefix)) {
      final encoded = wireId.substring(prefix.length).split('.');
      final decoded = utf8.decode(base64Url.decode(encoded.last));
      if (encoded.length == 1) {
        localId = decoded;
      } else if (encoded.first == _installation && deviceId == _installation) {
        localId = decoded;
        deviceId = _legacyDevice;
      }
    }
    return LearningEvent.fromMap({
      'eventId': localId,
      'userId': row['user_id'],
      'deviceId': deviceId,
      'itemId': row['item_id'],
      'skill': row['skill'],
      'occurredAt': row['occurred_at'],
      'correct': row['correct'],
      'latencyMs': row['latency_ms'],
      'hintCount': row['hint_count'],
      'retryCount': row['retry_count'],
      'response': row['response'],
    });
  }
}

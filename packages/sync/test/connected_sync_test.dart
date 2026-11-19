import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:persistence/persistence.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sync/sync.dart';
import 'package:test/test.dart';

const owner = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const other = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

void main() {
  test('manual sync sends local progress once and applies cloud events',
      () async {
    final repository = await LocalLearningRepository.inMemory();
    addTearDown(repository.close);
    final requests = <http.Request>[];
    final cloud = <Map<String, dynamic>>[];
    var lateRowVisible = false;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: _mockClient((request) async {
        if (request.url.path.endsWith('/token')) {
          return _session(owner);
        }
        requests.add(request);
        if (request.method == 'POST') {
          final rows =
              (jsonDecode(request.body) as List).cast<Map<String, dynamic>>();
          cloud.addAll(rows.map((row) => {
                ...row,
                'uploaded_at': '2026-11-19T10:00:00Z',
              }));
          return http.Response('', 201);
        }
        expect(request.url.queryParameters['user_id'], 'eq.$owner');
        if (request.url.queryParameters['select'] == 'event_id') {
          return _json(
              cloud.map((row) => {'event_id': row['event_id']}).toList());
        }
        if (request.url.queryParameters.containsKey('or')) return _json([]);
        expect(
          request.url.queryParameters['uploaded_at'],
          lateRowVisible ? 'gte.2026-11-19T09:59:00.000Z' : isNull,
        );
        return _json([
          ...cloud,
          if (lateRowVisible)
            {
              ...cloud.single,
              'event_id': 'late-commit',
              'device_id': 'remote-device',
              'uploaded_at': '2026-11-19T10:00:30Z',
            },
          {
            ...cloud.single,
            'event_id': 'remote-device-1',
            'device_id': 'remote-device',
            'occurred_at': '2026-01-01T00:00:00Z',
            'uploaded_at': '2026-11-19T10:01:00Z',
          },
        ]);
      }),
    );
    addTearDown(client.dispose);
    final service = LocalSyncService(
      repository: repository,
      cursorKey: SupabaseSyncTransport.cursorKey,
      resolveTransport: () =>
          SupabaseSyncTransport.forRepository(client, repository),
    );
    addTearDown(service.dispose);
    await repository.database.execute(
      'INSERT INTO sync_cursor (key, value) VALUES (?, ?)',
      ['events', SyncCursor.composite(DateTime.utc(2030), 'legacy').value],
    );

    await repository.recordReview(ReviewAttempt(
      itemId: 'ㄅ',
      skill: Skill.recognition,
      correct: true,
      occurredAt: DateTime.utc(2026, 11, 19),
    ));
    final guest = await service.syncNow();
    expect(guest.status, SyncStatus.localOnly);
    expect(requests, isEmpty);
    expect(await repository.pendingEvents(), hasLength(1));

    await client.auth
        .signInWithPassword(email: 'test@example.com', password: 'test');
    final synced = await service.syncNow();
    expect(synced.status, SyncStatus.synced);
    expect(synced.uploadedCount, 1);
    expect(await repository.pendingEvents(), isEmpty);
    expect(cloud.single['user_id'], owner);
    expect(cloud.single['event_id'], startsWith('bpm.$owner.'));
    expect(cloud.single['device_id'], isNot('local-device'));
    expect(
      (await repository.events.all()).map((event) => event.eventId),
      unorderedEquals(['local-device-1', 'remote-device-1']),
    );

    lateRowVisible = true;
    final retry = await service.syncNow();
    expect(retry.status, SyncStatus.synced);
    expect(requests.where((request) => request.method == 'POST'), hasLength(1));
    expect(
      (await repository.events.all()).map((event) => event.eventId),
      unorderedEquals(['local-device-1', 'remote-device-1', 'late-commit']),
    );
    expect(
        requests.last.url.queryParameters['or'], contains('uploaded_at.gt.'));
  });

  test('another account cannot reuse the local cloud sync binding', () async {
    final repository = await LocalLearningRepository.inMemory();
    addTearDown(repository.close);
    var currentUser = owner;
    var apiCalls = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: _mockClient((request) async {
        if (request.url.path.endsWith('/token')) return _session(currentUser);
        apiCalls++;
        return _json([]);
      }),
    );
    addTearDown(client.dispose);
    final service = LocalSyncService(
      repository: repository,
      resolveTransport: () =>
          SupabaseSyncTransport.forRepository(client, repository),
    );
    addTearDown(service.dispose);

    await client.auth
        .signInWithPassword(email: 'first@example.com', password: 'test');
    expect((await service.syncNow()).status, SyncStatus.synced);
    final initialCalls = apiCalls;
    currentUser = other;
    await client.auth
        .signInWithPassword(email: 'second@example.com', password: 'test');
    expect((await service.syncNow()).status, SyncStatus.accountMismatch);
    expect(apiCalls, initialCalls);
  });

  test('an HTTP authorization failure is not classified as offline', () async {
    final repository = await LocalLearningRepository.inMemory();
    addTearDown(repository.close);
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: _mockClient((request) async {
        if (request.url.path.endsWith('/token')) return _session(owner);
        return _json({'code': '42501', 'message': 'Permission denied'}, 403);
      }),
    );
    addTearDown(client.dispose);
    await client.auth
        .signInWithPassword(email: 'test@example.com', password: 'test');
    final service = LocalSyncService(
      repository: repository,
      resolveTransport: () =>
          SupabaseSyncTransport.forRepository(client, repository),
    );
    addTearDown(service.dispose);
    expect((await service.syncNow()).status, SyncStatus.error);
  });
}

MockClient _mockClient(Future<http.Response> Function(http.Request) handle) =>
    MockClient((request) async {
      final response = await handle(request);
      return http.Response.bytes(
        response.bodyBytes,
        response.statusCode,
        request: request,
        headers: response.headers,
      );
    });

http.Response _session(String id) {
  final claims = base64Url
      .encode(utf8.encode(jsonEncode({
        'sub': id,
        'exp': DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
      })))
      .replaceAll('=', '');
  return _json({
    'access_token': 'eyJhbGciOiJIUzI1NiJ9.$claims.dGVzdA',
    'refresh_token': 'test-refresh-token',
    'expires_in': 3600,
    'token_type': 'bearer',
    'user': {
      'id': id,
      'aud': 'authenticated',
      'app_metadata': {},
      'created_at': '2026-01-01T00:00:00Z',
    },
  });
}

http.Response _json(Object value, [int status = 200]) => http.Response(
      jsonEncode(value),
      status,
      headers: {'content-type': 'application/json'},
    );

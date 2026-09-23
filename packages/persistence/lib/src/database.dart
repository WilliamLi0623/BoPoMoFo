import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'tables.dart';

/// Small Drift-backed database facade used by the DAOs.
class LocalDatabase {
  final DatabaseConnection connection;
  late final _TransactionUser _transactionUser;

  LocalDatabase._(this.connection, [_TransactionUser? transactionUser])
      : _transactionUser = transactionUser ?? _TransactionUser(connection);

  factory LocalDatabase.inMemory() =>
      LocalDatabase._(DatabaseConnection(NativeDatabase.memory()));

  factory LocalDatabase.atPath(String path) =>
      LocalDatabase._(DatabaseConnection(NativeDatabase(File(path))));

  QueryExecutor get executor => _transactionUser.executor;

  Future<void> open() async {
    await _transactionUser.doWhenOpened((_) async {});
    for (final statement in createSchema) {
      await execute(statement);
    }
    final rows =
        await select('SELECT version FROM schema_info WHERE singleton = 1');
    if (rows.isEmpty) {
      await execute(
          'INSERT INTO schema_info (singleton, version) VALUES (1, ?)',
          [schemaVersion]);
    } else {
      final installed = rows.single['version']! as int;
      if (installed > schemaVersion) {
        throw StateError(
            'Database schema $installed is newer than $schemaVersion');
      }
      if (installed < schemaVersion) {
        await migrate(installed, schemaVersion);
      }
    }
  }

  /// Applies additive migrations one version at a time. The schema marker is
  /// updated only after that version's DDL succeeds.
  Future<void> migrate(int from, int to) async {
    if (from > to) throw ArgumentError.value(from, 'from');
    var version = from;
    while (version < to) {
      switch (version) {
        case 1:
          await execute('''
            ALTER TABLE device_identity
            ADD COLUMN next_event_sequence INTEGER NOT NULL DEFAULT 0
          ''');
          version = 2;
        default:
          throw StateError('No migration registered for schema $version');
      }
      await execute(
        'UPDATE schema_info SET version = ? WHERE singleton = 1',
        [version],
      );
    }
  }

  Future<T> transaction<T>(Future<T> Function(LocalDatabase tx) action) =>
      _transactionUser.transaction(
        () => action(LocalDatabase._(connection, _transactionUser)),
      );

  Future<List<Map<String, Object?>>> select(
    String statement, [
    List<Object?> args = const [],
  ]) async {
    final rows = await _transactionUser
        .customSelect(
          statement,
          variables: args.map((value) => Variable(value)).toList(),
        )
        .get();
    return rows.map((row) => row.data).toList(growable: false);
  }

  Future<void> execute(String statement, [List<Object?> args = const []]) =>
      _transactionUser.customStatement(statement, args);

  Future<String> allocateEventId(String requestedDeviceId) async {
    final rows = await select(
      'SELECT device_id, next_event_sequence FROM device_identity WHERE singleton = 1',
    );
    if (rows.isEmpty) {
      await execute('''
        INSERT INTO device_identity
        (singleton, device_id, platform, app_version, next_event_sequence)
        VALUES (1, ?, 'unknown', 'unknown', 1)
      ''', [requestedDeviceId]);
      return '$requestedDeviceId-1';
    }
    final row = rows.single;
    final persistedDeviceId = row['device_id']! as String;
    final next = (row['next_event_sequence']! as int) + 1;
    await execute(
      'UPDATE device_identity SET next_event_sequence = ? WHERE singleton = 1',
      [next],
    );
    return '$persistedDeviceId-$next';
  }

  Future<void> close() => connection.close();
}

/// Gives the raw connection Drift transaction semantics without requiring a
/// generated database class for this SQL-first schema.
class _TransactionUser extends GeneratedDatabase {
  _TransactionUser(super.connect);

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo> get allTables => const <TableInfo>[];
}

import 'package:domain/domain.dart';

enum SyncStatus { localOnly, pending, synced, offline, accountMismatch, error }

class SyncCursor {
  final String value;
  final DateTime? occurredAt;
  final String? eventId;

  const SyncCursor(this.value)
      : occurredAt = null,
        eventId = null;

  const SyncCursor._legacy(this.value, this.occurredAt) : eventId = null;

  SyncCursor.composite(DateTime occurredAt, String eventId)
      : value = '${occurredAt.toUtc().toIso8601String()}|$eventId',
        occurredAt = occurredAt.toUtc(),
        eventId = eventId;

  factory SyncCursor.fromValue(String value) {
    final separator = value.lastIndexOf('|');
    if (separator > 0 && separator < value.length - 1) {
      final occurredAt = DateTime.tryParse(value.substring(0, separator));
      if (occurredAt != null) {
        return SyncCursor.composite(occurredAt, value.substring(separator + 1));
      }
    }
    final legacyOccurredAt = DateTime.tryParse(value);
    if (legacyOccurredAt != null) {
      return SyncCursor._legacy(value, legacyOccurredAt.toUtc());
    }
    return SyncCursor(value);
  }

  static const initial = SyncCursor('');

  @override
  bool operator ==(Object other) => other is SyncCursor && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'SyncCursor($value)';
}

class UploadResult {
  final Set<String> acknowledgedIds;

  UploadResult({required Iterable<String> acknowledgedIds})
      : acknowledgedIds = acknowledgedIds.toSet();
}

class SyncTransportUnavailable implements Exception {
  final String message;

  const SyncTransportUnavailable(this.message);

  @override
  String toString() => 'SyncTransportUnavailable: $message';
}

class SyncAccountMismatch implements Exception {
  const SyncAccountMismatch();
}

class DownloadResult {
  final List<LearningEvent> events;
  final SyncCursor nextCursor;

  DownloadResult({required Iterable<LearningEvent> events, required this.nextCursor})
      : events = List.unmodifiable(events);
}

class SyncState {
  final SyncStatus status;
  final int pendingCount;
  final DateTime? lastSuccessfulSync;
  final String? message;
  final Future<SyncResult> Function()? retry;

  const SyncState({
    required this.status,
    this.pendingCount = 0,
    this.lastSuccessfulSync,
    this.message,
    this.retry,
  });
}

class SyncResult {
  final SyncStatus status;
  final int uploadedCount;
  final int downloadedCount;
  final String? message;

  const SyncResult({
    required this.status,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
    this.message,
  });
}

import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:srs/srs.dart' as srs;

const currentSchemaVersion = 1;
const currentContentVersion = 'content-1';
const currentAlgorithmVersion = srs.algorithmVersion;
const supportedContentVersions = <String>{currentContentVersion};
const supportedAlgorithmVersions = <String>{currentAlgorithmVersion};

class LearningDataValidationException extends FormatException {
  const LearningDataValidationException(super.message);
}

class LearningDataEnvelope {
  final int schemaVersion;
  final String contentVersion;
  final String algorithmVersion;
  final Map<String, Object?> device;
  final List<LearningEvent> events;

  const LearningDataEnvelope({
    required this.schemaVersion,
    required this.contentVersion,
    required this.algorithmVersion,
    required this.device,
    required this.events,
  });

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'contentVersion': contentVersion,
        'algorithmVersion': algorithmVersion,
        'device': _contractDevice(device),
        'events': events.map((event) => event.toMap()).toList(growable: false),
      };

  String encode() => jsonEncode(toJson());

  static LearningDataEnvelope decode(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Learning data must be a JSON object');
    }
    final schema = value['schemaVersion'];
    final contentVersion = value['contentVersion'];
    final algorithmVersion = value['algorithmVersion'];
    final device = value['device'];
    final events = value['events'];
    if (schema is! int || schema != currentSchemaVersion ||
        contentVersion is! String ||
        !supportedContentVersions.contains(contentVersion) ||
        algorithmVersion is! String ||
        !supportedAlgorithmVersions.contains(algorithmVersion) ||
        device is! Map || events is! List) {
      throw const LearningDataValidationException(
        'Unsupported learning data envelope',
      );
    }
    final contractDevice = _contractDevice(device.cast<String, Object?>());
    final deviceId = contractDevice['deviceId'];
    if (deviceId is! String || deviceId.isEmpty) {
      throw const LearningDataValidationException(
        'Learning data is missing device metadata',
      );
    }
    return LearningDataEnvelope(
      schemaVersion: schema,
      contentVersion: contentVersion,
      algorithmVersion: algorithmVersion,
      device: contractDevice,
      events: events
          .map((event) => LearningEvent.fromMap((event as Map).cast<String, Object?>()))
          .toList(growable: false),
    );
  }

  static Map<String, Object?> _contractDevice(Map<String, Object?> source) {
    final result = <String, Object?>{};
    for (final key in const ['deviceId', 'platform', 'appVersion']) {
      final value = source[key];
      if (value is String && value.isNotEmpty) result[key] = value;
    }
    return result;
  }
}

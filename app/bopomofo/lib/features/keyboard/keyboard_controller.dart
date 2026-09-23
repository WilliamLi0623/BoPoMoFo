import 'package:domain/domain.dart';
import 'package:flutter/services.dart';
import 'package:phonology/phonology.dart' as phonology;

import '../../bootstrap.dart';

class KeyboardMetrics {
  const KeyboardMetrics({required this.attempts, required this.correct, required this.elapsed});

  final int attempts;
  final int correct;
  final Duration elapsed;

  double get accuracy => attempts == 0 ? 0 : correct / attempts;
  double get cpm => elapsed.inSeconds == 0 ? 0 : correct * 60 / elapsed.inSeconds;
}

class ListeningPrompt {
  const ListeningPrompt({required this.label, this.assetPath});

  final String label;
  final String? assetPath;

  bool get hasLocalAsset => assetPath != null && assetPath!.isNotEmpty;
}

class KeyboardController {
  KeyboardController({required this.repository, DateTime Function()? now})
      : _now = now ?? DateTime.now,
        _startedAt = (now ?? DateTime.now)();

  final AppLearningRepository repository;
  final DateTime Function() _now;
  final DateTime _startedAt;
  int _attempts = 0;
  int _correct = 0;
  String _target = phonology.symbols.first.glyph;
  bool _labelsVisible = true;

  String get target => _target;
  bool get labelsVisible => _labelsVisible;
  KeyboardMetrics get metrics => KeyboardMetrics(
        attempts: _attempts,
        correct: _correct,
        elapsed: _now().difference(_startedAt),
      );

  void setTarget(String glyph) {
    if (phonology.symbols.any((symbol) => symbol.glyph == glyph)) _target = glyph;
  }

  void toggleLabels() => _labelsVisible = !_labelsVisible;

  Future<bool> handleKey(String key) async {
    final normalized = key.trim().toLowerCase();
    String? glyph;
    for (final symbol in phonology.symbols) {
      if (symbol.keyboardKey == normalized || symbol.glyph == key) {
        glyph = symbol.glyph;
        break;
      }
    }
    final correct = glyph == _target;
    _attempts++;
    if (correct) _correct++;
    await repository.recordReview(ReviewAttempt(
      itemId: _target,
      skill: Skill.keyboard,
      correct: correct,
      occurredAt: _now().toUtc(),
      latencyMs: _now().difference(_startedAt).inMilliseconds,
      response: key,
    ));
    return correct;
  }

  Future<bool> handlePhysicalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return Future.value(false);
    return handleKey(event.character ?? event.logicalKey.keyLabel);
  }

  ListeningPrompt listeningPrompt({String? localAssetPath}) => ListeningPrompt(
        label: _target,
        assetPath: localAssetPath,
      );
}

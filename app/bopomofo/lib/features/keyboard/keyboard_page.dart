import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:phonology/phonology.dart' as phonology;

import '../../bootstrap.dart';
import '../../l10n/app_localizations.dart';
import 'keyboard_controller.dart';

enum _KeyboardStatus { correct, retry, listeningReady, listeningUnavailable }

class KeyboardPage extends StatefulWidget {
  const KeyboardPage({required this.learningEngine, required this.repository, super.key});

  final LearningEngine learningEngine;
  final AppLearningRepository repository;

  @override
  State<KeyboardPage> createState() => _KeyboardPageState();
}

class _KeyboardPageState extends State<KeyboardPage> {
  late final KeyboardController _controller = KeyboardController(repository: widget.repository);
  final FocusNode _focusNode = FocusNode(debugLabel: 'bopomofo-keyboard');
  _KeyboardStatus? _status;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handlePhysicalEvent(KeyEvent event) async {
    if (event is! KeyDownEvent) return;
    final correct = await _controller.handlePhysicalKey(event);
    if (mounted) setState(() => _status = correct ? _KeyboardStatus.correct : _KeyboardStatus.retry);
  }

  void _showListeningState(ListeningPrompt prompt) {
    setState(() {
      _status = prompt.hasLocalAsset ? _KeyboardStatus.listeningReady : _KeyboardStatus.listeningUnavailable;
    });
  }

  @override
  Widget build(BuildContext context) {
    final labels = AppLocalizations.of(context)!;
    final metrics = _controller.metrics;
    final listening = _controller.listeningPrompt();
    final statusText = switch (_status) {
      _KeyboardStatus.correct => labels.keyboardCorrect,
      _KeyboardStatus.retry => labels.keyboardTryAgain,
      _KeyboardStatus.listeningReady => labels.keyboardListeningReady,
      _KeyboardStatus.listeningUnavailable => labels.keyboardListeningUnavailable(listening.label),
      null => null,
    };
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) => unawaited(_handlePhysicalEvent(event)),
      child: ListView(
        key: const ValueKey('keyboard-page'),
        padding: const EdgeInsets.all(24),
        children: [
        Text(labels.keyboardPractice, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(_controller.labelsVisible ? labels.keyboardTypeSymbol(_controller.target) : labels.keyboardTypeHiddenSymbol),
        Text(labels.keyboardMetrics((metrics.accuracy * 100).round(), metrics.cpm.toStringAsFixed(0)), key: const ValueKey('keyboard-metrics')),
        TextButton(
          key: const ValueKey('keyboard-toggle-labels'),
          onPressed: () => setState(_controller.toggleLabels),
          child: Text(_controller.labelsVisible ? labels.keyboardHideLabels : labels.keyboardShowLabels),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final symbol in phonology.symbols)
              OutlinedButton(
                key: ValueKey('keyboard-key-${symbol.keyboardKey}'),
                onPressed: () async {
                  final correct = await _controller.handleKey(symbol.keyboardKey);
                  if (mounted) setState(() => _status = correct ? _KeyboardStatus.correct : _KeyboardStatus.retry);
                },
                child: Text(_controller.labelsVisible ? symbol.glyph : symbol.keyboardKey),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (statusText != null) Text(statusText, key: const ValueKey('keyboard-status')),
        const SizedBox(height: 16),
        Text(labels.keyboardListeningPrompt, style: Theme.of(context).textTheme.titleMedium),
        Text(labels.keyboardAudioOptional),
        TextButton(
          key: const ValueKey('keyboard-listening'),
          onPressed: () => _showListeningState(listening),
          child: Text(labels.keyboardPlayListeningPrompt),
        ),
        if (_status == _KeyboardStatus.listeningUnavailable)
          Text(statusText!, key: const ValueKey('keyboard-listening-unavailable')),
      ],
      ),
    );
  }
}

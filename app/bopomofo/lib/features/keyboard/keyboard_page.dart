import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phonology/phonology.dart' as phonology;

import '../../bootstrap.dart';
import 'keyboard_controller.dart';

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
  String? _status;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handlePhysicalEvent(KeyEvent event) async {
    if (event is! KeyDownEvent) return;
    final correct = await _controller.handlePhysicalKey(event);
    if (mounted) setState(() => _status = correct ? 'Correct' : 'Try again');
  }

  void _showListeningState(ListeningPrompt prompt) {
    setState(() {
      _status = prompt.hasLocalAsset
          ? 'Listening asset ready: ${prompt.assetPath}'
          : 'Listening unavailable offline for ${prompt.label}.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _controller.metrics;
    final listening = _controller.listeningPrompt();
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) => unawaited(_handlePhysicalEvent(event)),
      child: ListView(
        key: const ValueKey('keyboard-page'),
        padding: const EdgeInsets.all(24),
        children: [
        Text('Keyboard practice', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(_controller.labelsVisible ? 'Type this symbol: ${_controller.target}' : 'Type the hidden symbol'),
        Text('Accuracy ${(metrics.accuracy * 100).round()}% · CPM ${metrics.cpm.toStringAsFixed(0)}', key: const ValueKey('keyboard-metrics')),
        TextButton(
          key: const ValueKey('keyboard-toggle-labels'),
          onPressed: () => setState(_controller.toggleLabels),
          child: Text(_controller.labelsVisible ? 'Hide labels' : 'Show labels'),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final symbol in phonology.symbols)
              OutlinedButton(
                key: ValueKey('keyboard-key-${symbol.keyboardKey}'),
                onPressed: () async {
                  final correct = await _controller.handleKey(symbol.keyboardKey);
                  if (mounted) setState(() => _status = correct ? 'Correct' : 'Try again');
                },
                child: Text(_controller.labelsVisible ? symbol.glyph : symbol.keyboardKey),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_status != null) Text(_status!, key: const ValueKey('keyboard-status')),
        const SizedBox(height: 16),
        Text('Listening prompt', style: Theme.of(context).textTheme.titleMedium),
        const Text('Local audio is optional; this practice never requires network audio.'),
        TextButton(
          key: const ValueKey('keyboard-listening'),
          onPressed: () => _showListeningState(listening),
          child: const Text('Play listening prompt'),
        ),
        if (_status?.startsWith('Listening unavailable') ?? false)
          Text(_status!, key: const ValueKey('keyboard-listening-unavailable')),
      ],
      ),
    );
  }
}

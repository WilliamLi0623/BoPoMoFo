import 'package:bopomofo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:learning_engine/learning_engine.dart';
import 'package:phonology/phonology.dart' as phonology;

import 'audio_prompt_player.dart';

/// Renders one serialized prompt and reports its canonical response string.
/// Session feedback, persistence, and progression belong to the caller.
class QuestionView extends StatefulWidget {
  const QuestionView({
    super.key,
    required this.prompt,
    required this.audioPlayer,
    required this.onSubmit,
    required this.disabled,
    this.initialResponse,
  });

  final QuizPrompt prompt;
  final AudioPromptPlayer audioPlayer;
  final ValueChanged<String> onSubmit;
  final bool disabled;

  /// Canonical response already saved for this prompt, if answered.
  final String? initialResponse;

  @override
  State<QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<QuestionView> {
  final _recallController = TextEditingController();
  final List<String> _composition = [];
  bool _submitted = false;
  bool _isPlaying = false;
  String? _audioError;
  int _playbackGeneration = 0;

  @override
  void initState() {
    super.initState();
    _restoreResponse();
  }

  void _restoreResponse() {
    final response = widget.initialResponse;
    _recallController.text = response ?? '';
    _composition
      ..clear()
      ..addAll((response ?? '').runes.map(String.fromCharCode));
    _submitted = response != null;
  }

  @override
  void didUpdateWidget(covariant QuestionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final promptChanged = oldWidget.prompt.id != widget.prompt.id ||
        oldWidget.prompt.audioAssetId != widget.prompt.audioAssetId;
    if (promptChanged) {
      _playbackGeneration++;
      _isPlaying = false;
      _audioError = null;
    }
    if (promptChanged || oldWidget.initialResponse != widget.initialResponse) {
      _restoreResponse();
    }
  }

  @override
  void dispose() {
    _recallController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _promptText(labels),
            key: const ValueKey('quiz-question-prompt'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          _buildControl(labels),
          if (widget.initialResponse != null) ...[
            const SizedBox(height: 12),
            Text('${labels.quizResponseLabel}: ${widget.initialResponse}',
                key: const ValueKey('quiz-saved-response')),
          ],
        ],
      ),
    );
  }

  String _promptText(AppLocalizations labels) {
    final arguments = widget.prompt.promptArguments;
    return switch (widget.prompt.promptKey) {
      'quiz.recognition' =>
        labels.quizPromptRecognition(arguments['glyph'] ?? ''),
      'quiz.recall' => labels.quizPromptRecall(arguments['pinyin'] ?? ''),
      'quiz.composition' =>
        labels.quizPromptComposition(arguments['pinyin'] ?? ''),
      'quiz.listening' => labels.quizPromptListening,
      'quiz.keyboard' => labels.quizPromptKeyboard(arguments['pinyin'] ?? ''),
      _ => labels.quizPromptUnavailable,
    };
  }

  Widget _buildControl(AppLocalizations labels) => switch (widget.prompt.type) {
        QuizType.recognition => _buildChoices(labels),
        QuizType.recall => _buildRecall(labels),
        QuizType.composition => _buildComposition(labels),
        QuizType.listening => _buildListening(labels),
        QuizType.keyboard => _buildKeyboard(labels),
      };

  Widget _buildChoices(AppLocalizations labels) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final answer in widget.prompt.options.toSet())
            _answerButton(
              key: ValueKey('quiz-option-$answer'),
              label: labels.quizSelectAnswer(answer),
              answer: answer,
            ),
        ],
      );

  Widget _buildRecall(AppLocalizations labels) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('quiz-recall-input'),
            controller: _recallController,
            enabled: _isEnabled,
            textInputAction: TextInputAction.done,
            onSubmitted: _submit,
            decoration: InputDecoration(
              labelText: labels.quizResponseLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          _submitButton(labels, () => _submit(_recallController.text)),
        ],
      );

  Widget _buildComposition(AppLocalizations labels) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: _composition.isEmpty
                ? labels.quizCompositionEmpty
                : labels.quizCompositionAnswer(_composition.join()),
            liveRegion: true,
            excludeSemantics: true,
            child: Text(
              _composition.isEmpty ? ' ' : _composition.join(),
              key: const ValueKey('quiz-composition-answer'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final symbol in widget.prompt.options.toSet())
                if (!_composition.contains(symbol))
                  _actionButton(
                    key: ValueKey('quiz-tile-$symbol'),
                    label: labels.quizAddSymbol(symbol),
                    onPressed: _isEnabled
                        ? () => setState(() => _composition.add(symbol))
                        : null,
                    child: Text(symbol),
                  ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton(
                key: const ValueKey('quiz-composition-undo'),
                label: labels.quizUndoSymbol,
                onPressed: _isEnabled && _composition.isNotEmpty
                    ? () => setState(() => _composition.removeLast())
                    : null,
                child: Text(labels.quizUndoSymbol),
              ),
              _actionButton(
                key: const ValueKey('quiz-composition-clear'),
                label: labels.quizClearResponse,
                onPressed: _isEnabled && _composition.isNotEmpty
                    ? () => setState(_composition.clear)
                    : null,
                child: Text(labels.quizClearResponse),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _submitButton(labels, () => _submit(_composition.join())),
        ],
      );

  Widget _buildListening(AppLocalizations labels) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _actionButton(
            key: const ValueKey('quiz-play-audio'),
            label: _isPlaying ? labels.quizPlayingAudio : labels.quizPlayAudio,
            onPressed:
                _isEnabled && !_isPlaying && !_submitted ? _playAudio : null,
            child: Text(labels.quizPlayAudio),
          ),
          if (_audioError != null) ...[
            const SizedBox(height: 8),
            Semantics(
              label: labels.quizAudioPlaybackFailed,
              liveRegion: true,
              excludeSemantics: true,
              child: Text(
                labels.quizAudioPlaybackFailed,
                key: const ValueKey('quiz-audio-error'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildChoices(labels),
        ],
      );

  Widget _buildKeyboard(AppLocalizations labels) => Focus(
        autofocus: _isEnabled,
        canRequestFocus: _isEnabled,
        onKeyEvent: (node, event) => _handlePhysicalKey(event),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final symbol in phonology.symbols)
              if (widget.prompt.options.contains(symbol.glyph))
                _actionButton(
                  key: ValueKey('quiz-key-${symbol.keyboardKey}'),
                  label: labels.quizTypeSymbolWithKey(
                    symbol.glyph,
                    symbol.keyboardKey,
                  ),
                  onPressed: _isEnabled && !_submitted
                      ? () => _submit(symbol.glyph)
                      : null,
                  child: Text(symbol.keyboardKey),
                ),
          ],
        ),
      );

  Widget _answerButton({
    required Key key,
    required String label,
    required String answer,
  }) =>
      _actionButton(
        key: key,
        label: label,
        onPressed: _isEnabled ? () => _submit(answer) : null,
        child: Text(answer),
      );

  Widget _submitButton(AppLocalizations labels, VoidCallback onPressed) =>
      _actionButton(
        key: const ValueKey('quiz-submit'),
        label: labels.quizSubmitAnswer,
        onPressed: _isEnabled ? onPressed : null,
        child: Text(labels.quizSubmitAnswer),
      );

  Widget _actionButton({
    required Key key,
    required String label,
    required VoidCallback? onPressed,
    required Widget child,
  }) =>
      Semantics(
        label: label,
        button: true,
        enabled: onPressed != null,
        onTap: onPressed,
        excludeSemantics: true,
        child: FilledButton(
          key: key,
          onPressed: onPressed,
          child: child,
        ),
      );

  bool get _isEnabled => !widget.disabled && !_submitted;

  KeyEventResult _handlePhysicalKey(KeyEvent event) {
    if (event is! KeyDownEvent || !_isEnabled) return KeyEventResult.ignored;
    final key = (event.character ?? event.logicalKey.keyLabel).trim();
    if (key.isEmpty) return KeyEventResult.ignored;
    final normalized = key.toLowerCase();
    for (final symbol in phonology.symbols) {
      if (symbol.keyboardKey.toLowerCase() == normalized ||
          symbol.glyph == key) {
        if (widget.prompt.options.contains(symbol.glyph)) {
          _submit(symbol.glyph);
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _submit(String response) {
    final canonicalResponse = response.trim();
    if (!_isEnabled || canonicalResponse.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitted = true);
    widget.onSubmit(canonicalResponse);
  }

  Future<void> _playAudio() async {
    final assetId = widget.prompt.audioAssetId;
    if (!_isEnabled || _isPlaying || assetId == null) return;
    final requestGeneration = _playbackGeneration;
    final promptId = widget.prompt.id;
    setState(() {
      _isPlaying = true;
      _audioError = null;
    });
    try {
      await widget.audioPlayer.play(assetId);
    } on Object {
      if (_isCurrentPlayback(requestGeneration, promptId)) {
        setState(() => _audioError = 'playback failed');
      }
    } finally {
      if (_isCurrentPlayback(requestGeneration, promptId)) {
        setState(() => _isPlaying = false);
      }
    }
  }

  bool _isCurrentPlayback(int generation, String promptId) =>
      mounted &&
      generation == _playbackGeneration &&
      promptId == widget.prompt.id;
}

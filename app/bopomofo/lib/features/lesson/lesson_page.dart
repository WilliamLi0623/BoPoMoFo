import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phonology/phonology.dart' as phonology;

import '../../l10n/app_localizations.dart';
import '../review/audio_asset_manifest.dart';
import '../review/audio_prompt_player.dart';
import 'learning_path.dart';

class LessonPage extends StatelessWidget {
  const LessonPage({
    required this.path,
    required this.onPractice,
    required this.onReview,
    this.audioOutput,
    super.key,
  });

  final LearningPath path;
  final VoidCallback onPractice;
  final VoidCallback onReview;
  final AudioPromptAudioOutput? audioOutput;

  @override
  Widget build(BuildContext context) {
    final labels = AppLocalizations.of(context)!;
    final (description, practiceLabel) = switch (path) {
      LearningPath.pinyin => (
          labels.lessonPathPinyin,
          labels.lessonPracticePinyin
        ),
      LearningPath.sounds => (
          labels.lessonPathSounds,
          labels.lessonPracticeSounds
        ),
      LearningPath.beginner => (
          labels.lessonPathBeginner,
          labels.lessonPracticeBeginner
        ),
    };
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(labels.lessonTitle,
            style: Theme.of(context).textTheme.headlineMedium),
        Text(description),
        const SizedBox(height: 16),
        switch (path) {
          LearningPath.pinyin => Card(
              child: Column(
                children: [
                  for (final pinyin in pinyinLessonExamples)
                    ListTile(
                        title: Text('$pinyin → ${phonology.toZhuyin(pinyin)}')),
                ],
              ),
            ),
          LearningPath.sounds => _PronunciationExamples(output: audioOutput),
          LearningPath.beginner => Card(
              child: Column(
                children: [
                  for (final example in beginnerLessonExamples)
                    _beginnerExample(phonology.toZhuyin(example)),
                ],
              ),
            ),
        },
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('lesson-start-path-practice'),
          onPressed: onPractice,
          child: Text(practiceLabel),
        ),
        OutlinedButton(onPressed: onReview, child: Text(labels.reviewDueItems)),
      ],
    );
  }

  Widget _beginnerExample(String syllable) {
    final symbols = syllable.runes.map(String.fromCharCode).toList();
    return ListTile(
      title: Text(symbols.first),
      subtitle: Text('${symbols.join(' + ')} = $syllable'),
    );
  }
}

class _PronunciationExamples extends StatefulWidget {
  const _PronunciationExamples({this.output});

  final AudioPromptAudioOutput? output;

  @override
  State<_PronunciationExamples> createState() => _PronunciationExamplesState();
}

class _PronunciationExamplesState extends State<_PronunciationExamples> {
  late final Future<AudioAssetManifest> _assets =
      AudioAssetManifest.loadBundled(rootBundle);
  OfflineAudioPromptPlayer? _player;
  bool _starting = false;
  bool _playbackFailed = false;

  Future<void> _play(AudioAssetManifest manifest, String id) async {
    setState(() {
      _starting = true;
      _playbackFailed = false;
    });
    try {
      final player = _player ??= OfflineAudioPromptPlayer(
        manifest: manifest,
        output: widget.output,
      );
      await player.play(id);
    } on Object {
      if (mounted) setState(() => _playbackFailed = true);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  void dispose() {
    final player = _player;
    if (player != null) unawaited(player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = AppLocalizations.of(context)!;
    return FutureBuilder<AudioAssetManifest>(
      future: _assets,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final manifest = snapshot.data;
        final prompts = manifest == null
            ? const []
            : starterPromptsForPath(LearningPath.sounds, manifest);
        if (manifest == null || prompts.isEmpty) {
          return Text(labels.quizAudioPlaybackFailed);
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final prompt in prompts)
                  OutlinedButton.icon(
                    key: ValueKey('lesson-audio-${prompt.audioAssetId}'),
                    onPressed: _starting
                        ? null
                        : () => _play(manifest, prompt.audioAssetId!),
                    icon: const Icon(Icons.volume_up),
                    label: Text(
                        labels.lessonPlayPronunciation(prompt.expectedAnswer)),
                  ),
                if (_playbackFailed)
                  Semantics(
                      liveRegion: true,
                      child: Text(labels.quizAudioPlaybackFailed)),
              ],
            ),
          ),
        );
      },
    );
  }
}

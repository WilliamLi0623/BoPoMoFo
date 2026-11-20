import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phonology/phonology.dart' as phonology;

import '../../l10n/app_localizations.dart';
import '../review/audio_asset_manifest.dart';
import '../review/audio_prompt_player.dart';
import 'learning_path.dart';

class LessonPage extends StatefulWidget {
  const LessonPage({
    required this.path,
    required this.onPractice,
    required this.onReview,
    this.loadCompleted,
    this.audioOutput,
    super.key,
  });

  final LearningPath path;
  final Future<bool?> Function(LearningLesson lesson) onPractice;
  final VoidCallback onReview;
  final Future<Set<String>> Function()? loadCompleted;
  final AudioPromptAudioOutput? audioOutput;

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  Set<String> _completed = const {};
  int _selected = 0;
  bool _pickedLesson = false;
  bool _opening = false;
  bool _loadFailed = false;

  List<LearningLesson> get _lessons => lessonsForPath(widget.path);

  @override
  void initState() {
    super.initState();
    unawaited(_readProgress(resume: true));
  }

  Future<void> _readProgress({bool resume = false}) async {
    final load = widget.loadCompleted;
    if (load == null) return;
    try {
      final completed = await load();
      if (!mounted) return;
      setState(() {
        _completed = completed;
        _loadFailed = false;
        if (resume && !_pickedLesson) {
          final first = _lessons.indexWhere(
            (lesson) => !completed.contains(lesson.scope),
          );
          _selected = first < 0 ? _lessons.length - 1 : first;
        }
      });
    } on Exception {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _practice(LearningLesson lesson) async {
    setState(() {
      _opening = true;
      _pickedLesson = true;
    });
    try {
      final next = await widget.onPractice(lesson);
      if (!mounted) return;
      if (next == true && lesson.hasNext) {
        setState(() => _selected = lesson.number);
      }
      await _readProgress();
    } on Exception {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = AppLocalizations.of(context)!;
    final lesson = _lessons[_selected];
    final (intro, practiceLabel) = switch (widget.path) {
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
    final description = switch (lesson.number) {
      2 => labels.lessonPracticeFinalsDescription,
      3 => labels.lessonPracticeNewInitialsDescription,
      _ => intro,
    };
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
            lesson.number == 1
                ? labels.lessonTitle
                : labels.courseLesson(lesson.number),
            style: Theme.of(context).textTheme.headlineMedium),
        Text(description),
        const SizedBox(height: 16),
        Text(_loadFailed
            ? labels.courseProgressUnavailable
            : labels.courseProgress(
                _lessons
                    .where((entry) => _completed.contains(entry.scope))
                    .length,
                _lessons.length,
              )),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final entry in _lessons)
              Semantics(
                label: _completed.contains(entry.scope)
                    ? labels.courseLessonComplete
                    : null,
                child: ChoiceChip(
                  key: ValueKey('course-lesson-${entry.number}'),
                  label: Text(labels.courseLesson(entry.number)),
                  selected: entry.number == lesson.number,
                  avatar: _completed.contains(entry.scope)
                      ? const Icon(Icons.check, size: 16)
                      : null,
                  onSelected: _opening
                      ? null
                      : (_) => setState(() {
                            _pickedLesson = true;
                            _selected = entry.number - 1;
                          }),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        switch (widget.path) {
          LearningPath.pinyin => Card(
              child: Column(
                children: [
                  for (final pinyin in lesson.examples)
                    ListTile(
                        title: Text('$pinyin → ${phonology.toZhuyin(pinyin)}')),
                ],
              ),
            ),
          LearningPath.sounds => _PronunciationExamples(
              key: ValueKey(lesson.scope),
              lesson: lesson,
              output: widget.audioOutput),
          LearningPath.beginner => Card(
              child: Column(
                children: [
                  for (final example in lesson.examples)
                    _beginnerExample(
                        phonology.toZhuyin(example), lesson.number == 2),
                ],
              ),
            ),
        },
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('lesson-start-path-practice'),
          onPressed: _opening ? null : () => _practice(lesson),
          child: Text(practiceLabel),
        ),
        OutlinedButton(
          onPressed: _opening ? null : widget.onReview,
          child: Text(labels.reviewDueItems),
        ),
      ],
    );
  }

  Widget _beginnerExample(String syllable, bool showFinal) {
    final symbols = syllable.runes.map(String.fromCharCode).toList();
    return ListTile(
      title: Text(showFinal ? symbols.last : symbols.first),
      subtitle: Text('${symbols.join(' + ')} = $syllable'),
    );
  }
}

class _PronunciationExamples extends StatefulWidget {
  const _PronunciationExamples({required this.lesson, this.output, super.key});

  final LearningLesson lesson;
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
            : starterPromptsForLesson(widget.lesson, manifest);
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

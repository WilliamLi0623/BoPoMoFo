import 'dart:async';

import 'package:bopomofo/features/review/audio_prompt_player.dart';
import 'package:bopomofo/features/review/question_view.dart';
import 'package:bopomofo/l10n/app_localizations.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_engine/learning_engine.dart';
import 'package:phonology/phonology.dart' as phonology;

void main() {
  testWidgets('composition can undo and clear an accidental selection',
      (tester) async {
    final submitted = <String>[];
    await _pumpQuestion(tester,
        type: QuizType.composition, onSubmit: submitted.add);
    await tester.tap(find.byKey(const ValueKey('quiz-tile-ㄚ')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quiz-composition-undo')));
    await tester.pump();
    expect(find.byKey(const ValueKey('quiz-tile-ㄚ')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz-tile-ㄅ')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quiz-composition-clear')));
    await tester.pump();
    expect(find.byKey(const ValueKey('quiz-tile-ㄅ')), findsOneWidget);
    expect(submitted, isEmpty);
    await tester.tap(find.byKey(const ValueKey('quiz-tile-ㄅ')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quiz-tile-ㄚ')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quiz-submit')));
    await tester.pump();
    expect(submitted, ['ㄅㄚ']);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('quiz-composition-clear')))
            .onPressed,
        isNull);
  });

  testWidgets('recall submission releases the soft keyboard focus',
      (tester) async {
    await _pumpQuestion(tester, type: QuizType.recall, onSubmit: (_) {});
    await tester.enterText(
        find.byKey(const ValueKey('quiz-recall-input')), 'ㄅㄚ');
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue);
    await tester.tap(find.byKey(const ValueKey('quiz-submit')));
    await tester.pump();
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isFalse);
  });

  testWidgets('recognition submits the selected canonical option',
      (tester) async {
    final submitted = <String>[];

    await _pumpQuestion(
      tester,
      type: QuizType.recognition,
      onSubmit: submitted.add,
    );

    expect(find.byKey(const ValueKey('quiz-option-zhuyin')), findsOneWidget);
    expect(find.bySemanticsLabel('Select answer zhuyin'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz-option-zhuyin')));

    expect(submitted, ['zhuyin']);
  });

  testWidgets('recall submits trimmed phonetic text', (tester) async {
    final submitted = <String>[];

    await _pumpQuestion(
      tester,
      type: QuizType.recall,
      onSubmit: submitted.add,
    );
    expect(find.bySemanticsLabel('Enter your response'), findsOneWidget);
    expect(find.bySemanticsLabel('Submit answer'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('quiz-recall-input')), '  ㄅㄚ  ');
    await tester.tap(find.byKey(const ValueKey('quiz-submit')));

    expect(submitted, ['ㄅㄚ']);
  });

  testWidgets('composition submits the order in which symbol tiles were picked',
      (tester) async {
    final submitted = <String>[];

    await _pumpQuestion(
      tester,
      type: QuizType.composition,
      onSubmit: submitted.add,
    );
    expect(find.bySemanticsLabel('Add symbol ㄅ'), findsOneWidget);
    expect(find.bySemanticsLabel('Add symbol ㄚ'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz-tile-ㄅ')));
    await tester.tap(find.byKey(const ValueKey('quiz-tile-ㄚ')));
    await tester.tap(find.byKey(const ValueKey('quiz-submit')));

    expect(submitted, ['ㄅㄚ']);
  });

  testWidgets('listening plays the supplied local asset and submits a choice',
      (tester) async {
    final submitted = <String>[];
    final player = _FakeAudioPromptPlayer();

    await _pumpQuestion(
      tester,
      type: QuizType.listening,
      audioPlayer: player,
      onSubmit: submitted.add,
    );
    expect(find.bySemanticsLabel('Play question audio'), findsOneWidget);
    expect(find.bySemanticsLabel('Select answer ㄅㄚ'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz-play-audio')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quiz-option-ㄅㄚ')));

    expect(player.playedAssetIds, ['local-ba']);
    expect(submitted, ['ㄅㄚ']);
  });

  testWidgets('keyboard accepts a virtual key and maps a physical key',
      (tester) async {
    final submitted = <String>[];

    await _pumpQuestion(
      tester,
      type: QuizType.keyboard,
      onSubmit: submitted.add,
    );
    expect(find.bySemanticsLabel('Type ㄇ using key a'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz-key-a')));
    expect(submitted, ['ㄇ']);

    submitted.clear();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpQuestion(
      tester,
      type: QuizType.keyboard,
      onSubmit: submitted.add,
    );
    expect(find.bySemanticsLabel('Type ㄇ using key a'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);

    expect(submitted, ['ㄇ']);
    expect(
      phonology.symbols
          .singleWhere((symbol) => symbol.glyph == 'ㄇ')
          .keyboardKey,
      'a',
    );
  });

  testWidgets('disabled response controls do not submit', (tester) async {
    final submitted = <String>[];

    await _pumpQuestion(
      tester,
      type: QuizType.recognition,
      disabled: true,
      onSubmit: submitted.add,
    );
    await tester.tap(find.byKey(const ValueKey('quiz-option-zhuyin')));

    expect(submitted, isEmpty);
  });

  testWidgets(
      'restored composition displays saved symbol order without submitting',
      (tester) async {
    final submitted = <String>[];
    await _pumpQuestion(tester,
        type: QuizType.composition,
        initialResponse: 'ㄚㄅ',
        disabled: true,
        onSubmit: submitted.add);

    expect(find.text('ㄚㄅ'), findsWidgets);
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('quiz-composition-answer')))
            .data,
        'ㄚㄅ');
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('quiz-submit')))
            .onPressed,
        isNull);
    expect(submitted, isEmpty);
  });

  for (final type in [
    QuizType.recognition,
    QuizType.listening,
    QuizType.keyboard
  ]) {
    testWidgets('restored ${type.name} shows the saved choice', (tester) async {
      await _pumpQuestion(tester,
          type: type,
          initialResponse: 'saved choice',
          disabled: true,
          onSubmit: (_) {});
      expect(find.byKey(const ValueKey('quiz-saved-response')), findsOneWidget);
      expect(find.textContaining('saved choice'), findsOneWidget);
    });
  }

  testWidgets('repeated taps submit an answer only once', (tester) async {
    final submitted = <String>[];

    await _pumpQuestion(
      tester,
      type: QuizType.recognition,
      onSubmit: submitted.add,
    );
    await tester.tap(find.byKey(const ValueKey('quiz-option-zhuyin')));
    await tester.tap(find.byKey(const ValueKey('quiz-option-zhuyin')));

    expect(submitted, ['zhuyin']);
  });

  testWidgets('playback failure remains unanswered and can be retried',
      (tester) async {
    final submitted = <String>[];
    final player = _FakeAudioPromptPlayer(failFirstPlay: true);

    await _pumpQuestion(
      tester,
      type: QuizType.listening,
      audioPlayer: player,
      onSubmit: submitted.add,
    );
    expect(find.bySemanticsLabel('Play question audio'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz-play-audio')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('quiz-audio-error')), findsOneWidget);
    expect(submitted, isEmpty);
    await tester.tap(find.byKey(const ValueKey('quiz-play-audio')));
    await tester.pump();

    expect(player.playedAssetIds, ['local-ba', 'local-ba']);
    expect(find.byKey(const ValueKey('quiz-audio-error')), findsNothing);
    expect(submitted, isEmpty);
  });

  for (final rejectOldPlayback in [false, true]) {
    testWidgets(
      'prompt replacement isolates ${rejectOldPlayback ? 'rejected' : 'resolved'} old playback',
      (tester) async {
        final firstGate = Completer<void>();
        final secondGate = Completer<void>();
        final player = _SerialFakeAudioPromptPlayer({
          'local-ba': firstGate,
          'local-ma': secondGate,
        });
        final firstPrompt = _listeningPrompt('first', 'local-ba');
        final secondPrompt = _listeningPrompt('second', 'local-ma');

        await _pumpPrompt(tester, firstPrompt, player);
        await tester.tap(find.byKey(const ValueKey('quiz-play-audio')));
        await tester.pump();

        await _pumpPrompt(tester, secondPrompt, player);
        await tester.tap(find.byKey(const ValueKey('quiz-play-audio')));
        await tester.pump();

        expect(player.playedAssetIds, ['local-ba', 'local-ma']);
        expect(player.startedAssetIds, ['local-ba']);
        expect(player.activeAssetIds, ['local-ba']);

        if (rejectOldPlayback) {
          firstGate.completeError(
            const AudioPromptPlaybackException(message: 'old fake failure'),
          );
        } else {
          firstGate.complete();
        }
        await tester.pump();
        await tester.pump();

        expect(player.startedAssetIds, ['local-ba', 'local-ma']);
        expect(player.activeAssetIds, ['local-ma']);
        expect(find.byKey(const ValueKey('quiz-audio-error')), findsNothing);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('quiz-play-audio')),
              )
              .onPressed,
          isNull,
          reason: 'the replacement playback must remain in progress',
        );

        secondGate.complete();
        await tester.pump();
        await tester.pump();
        expect(player.activeAssetIds, isEmpty);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('quiz-play-audio')),
              )
              .onPressed,
          isNotNull,
        );
        expect(find.byKey(const ValueKey('quiz-audio-error')), findsNothing);
      },
    );
  }
}

Future<void> _pumpQuestion(
  WidgetTester tester, {
  required QuizType type,
  AudioPromptPlayer? audioPlayer,
  bool disabled = false,
  String? initialResponse,
  required ValueChanged<String> onSubmit,
}) async {
  await _pumpPrompt(
      tester, _prompt(type), audioPlayer ?? _FakeAudioPromptPlayer(),
      onSubmit: onSubmit, disabled: disabled, initialResponse: initialResponse);
}

Future<void> _pumpPrompt(
  WidgetTester tester,
  QuizPrompt prompt,
  AudioPromptPlayer audioPlayer, {
  ValueChanged<String>? onSubmit,
  bool disabled = false,
  String? initialResponse,
}) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: QuestionView(
        prompt: prompt,
        audioPlayer: audioPlayer,
        onSubmit: onSubmit ?? (_) {},
        disabled: disabled,
        initialResponse: initialResponse,
      ),
    ),
  ));
}

QuizPrompt _listeningPrompt(String id, String assetId) => QuizPrompt(
      id: id,
      itemId: 'ba',
      skill: Skill.recognition,
      type: QuizType.listening,
      promptKey: 'quiz.listening',
      promptArguments: const {},
      expectedAnswer: 'ã„…ã„š',
      options: const ['ã„†ã„š', 'ã„…ã„š'],
      audioAssetId: assetId,
    );

QuizPrompt _prompt(QuizType type) => QuizPrompt(
      id: 'prompt-${type.name}',
      itemId: 'ba',
      skill: Skill.recognition,
      type: type,
      promptKey: 'quiz.${type.name}',
      promptArguments: switch (type) {
        QuizType.recognition => const {'glyph': 'ㄅ'},
        QuizType.recall => const {'pinyin': 'ba'},
        QuizType.composition => const {'pinyin': 'ba'},
        QuizType.listening => const {},
        QuizType.keyboard => const {'pinyin': 'ma'},
      },
      expectedAnswer: switch (type) {
        QuizType.recognition => 'zhuyin',
        QuizType.recall => 'ㄅㄚ',
        QuizType.composition => 'ㄅㄚ',
        QuizType.listening => 'ㄅㄚ',
        QuizType.keyboard => 'ㄇ',
      },
      options: switch (type) {
        QuizType.recognition => const ['pinyin', 'zhuyin'],
        QuizType.recall => const ['ㄅㄚ', 'ㄆㄚ'],
        QuizType.composition => const ['ㄅ', 'ㄚ'],
        QuizType.listening => const ['ㄆㄚ', 'ㄅㄚ'],
        QuizType.keyboard => const ['ㄆ', 'ㄇ'],
      },
      audioAssetId: type == QuizType.listening ? 'local-ba' : null,
    );

class _FakeAudioPromptPlayer implements AudioPromptPlayer {
  _FakeAudioPromptPlayer({this.failFirstPlay = false});

  final bool failFirstPlay;
  final playedAssetIds = <String>[];

  @override
  Future<void> play(String assetId) async {
    playedAssetIds.add(assetId);
    if (failFirstPlay && playedAssetIds.length == 1) {
      throw const AudioPromptPlaybackException(message: 'fake failure');
    }
  }

  @override
  Future<void> dispose() async {}
}

class _SerialFakeAudioPromptPlayer implements AudioPromptPlayer {
  _SerialFakeAudioPromptPlayer(this.gates);

  final Map<String, Completer<void>> gates;
  final playedAssetIds = <String>[];
  final startedAssetIds = <String>[];
  final activeAssetIds = <String>[];
  Future<void> _tail = Future<void>.value();

  @override
  Future<void> play(String assetId) {
    playedAssetIds.add(assetId);
    final playback = _tail.then((_) async {
      startedAssetIds.add(assetId);
      activeAssetIds.add(assetId);
      try {
        await gates[assetId]!.future;
      } finally {
        activeAssetIds.remove(assetId);
      }
    });
    _tail = playback.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return playback;
  }

  @override
  Future<void> dispose() async {}
}

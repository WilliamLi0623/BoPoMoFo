import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:bopomofo/features/review/audio_asset_manifest.dart';
import 'package:bopomofo/features/review/audio_prompt_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const manifest = AudioAssetManifest([
    AudioAssetEntry(
      id: 'cns11643-female-ba',
      pinyin: 'ba',
      expectedAnswer: 'ㄅㄚ',
      assetPath: 'assets/audio/F_ba.mp3',
      sourceArchiveEntry: 'female.zip/F_ba.mp3',
      attribution:
          'Ministry of Digital Affairs / CNS11643 Full Character Library',
      sourceUrl: 'https://www.cns11643.gov.tw/opendata/Voice.zip',
      license: 'Government Open Data License, Version 1.0',
    ),
    AudioAssetEntry(
      id: 'cns11643-female-ma',
      pinyin: 'ma',
      expectedAnswer: 'ㄇㄚ',
      assetPath: 'assets/audio/F_ma.mp3',
      sourceArchiveEntry: 'female.zip/F_ma.mp3',
      attribution:
          'Ministry of Digital Affairs / CNS11643 Full Character Library',
      sourceUrl: 'https://www.cns11643.gov.tw/opendata/Voice.zip',
      license: 'Government Open Data License, Version 1.0',
    ),
  ]);

  test('plays the bundled path resolved from a manifest ID', () async {
    final output = _RecordingAudioPromptOutput();
    final player = OfflineAudioPromptPlayer(manifest: manifest, output: output);

    await player.play('cns11643-female-ba');

    expect(output.events, ['play:audio/F_ba.mp3']);
  });

  test('production output applies the AssetSource cache prefix exactly once',
      () async {
    final pluginPlayer = _FakePluginAudioPlayer();
    final player = OfflineAudioPromptPlayer(
      manifest: manifest,
      output: AudioplayersAudioPromptOutput(player: pluginPlayer),
    );

    await player.play('cns11643-female-ba');

    expect(pluginPlayer.sources, hasLength(1));
    expect(pluginPlayer.sources.single, isA<AssetSource>());
    final source = pluginPlayer.sources.single as AssetSource;
    expect(source.path, 'audio/F_ba.mp3');
    expect(pluginPlayer.audioCache.prefix, 'assets/');
    expect('${pluginPlayer.audioCache.prefix}${source.path}',
        'assets/audio/F_ba.mp3');
    await player.dispose();
    expect(pluginPlayer.disposed, isTrue);
  });

  test('bundled asset cache returns a file URI usable on Windows', () async {
    final tempDirectory = await Directory.systemTemp.createTemp('audio-cache-');
    addTearDown(() => tempDirectory.delete(recursive: true));

    final cache = _TemporaryAudioCache(tempDirectory.path);
    final source = AssetSource('audio/F_ba.mp3');

    expect(cache.prefix, 'assets/');
    expect(source.path, 'audio/F_ba.mp3');
    final cachedUri = await cache.load(source.path);

    expect(cachedUri.scheme, 'file');
    expect(await File.fromUri(cachedUri).length(), greaterThan(0));
  });

  test('stops the current prompt before playing its replacement', () async {
    final output = _RecordingAudioPromptOutput();
    final player = OfflineAudioPromptPlayer(manifest: manifest, output: output);

    await player.play('cns11643-female-ba');
    await player.play('cns11643-female-ma');

    expect(output.events, [
      'play:audio/F_ba.mp3',
      'stop',
      'play:audio/F_ma.mp3',
    ]);
  });

  test('overlapping play calls stop the active prompt before replacement',
      () async {
    final output = _DelayedFirstAudioPromptOutput();
    final player = OfflineAudioPromptPlayer(manifest: manifest, output: output);

    final firstPlay = player.play('cns11643-female-ba');
    await output.firstPlayStarted.future;
    final secondPlay = player.play('cns11643-female-ma');

    expect(output.firstPlayFinished.isCompleted, isFalse);
    output.firstPlayFinished.complete();
    await Future.wait<void>([firstPlay, secondPlay]);

    expect(output.events, [
      'play:audio/F_ba.mp3',
      'stop',
      'play:audio/F_ma.mp3',
    ]);
  });

  test('wraps plugin playback failures in a recoverable playback error',
      () async {
    final output = _RecordingAudioPromptOutput(
      playError: StateError('plugin failed'),
    );
    final player = OfflineAudioPromptPlayer(manifest: manifest, output: output);

    await expectLater(
      player.play('cns11643-female-ba'),
      throwsA(
        isA<AudioPromptPlaybackException>().having(
          (error) => error.cause,
          'cause',
          isA<StateError>(),
        ),
      ),
    );
  });

  test('reports an unknown manifest ID as a recoverable playback error',
      () async {
    final output = _RecordingAudioPromptOutput();
    final player = OfflineAudioPromptPlayer(
      manifest: manifest,
      output: output,
    );

    await expectLater(
      player.play('missing-audio'),
      throwsA(isA<AudioPromptPlaybackException>()),
    );
    expect(output.events, isEmpty);
  });

  test('disposes the underlying output', () async {
    final output = _RecordingAudioPromptOutput();
    final player = OfflineAudioPromptPlayer(manifest: manifest, output: output);

    await player.dispose();

    expect(output.events, ['dispose']);
  });
}

class _RecordingAudioPromptOutput implements AudioPromptAudioOutput {
  _RecordingAudioPromptOutput({this.playError});

  final Object? playError;
  final events = <String>[];

  @override
  Future<void> playAsset(String assetPath) async {
    events.add('play:$assetPath');
    if (playError case final error?) throw error;
  }

  @override
  Future<void> stop() async {
    events.add('stop');
  }

  @override
  Future<void> dispose() async {
    events.add('dispose');
  }
}

class _TemporaryAudioCache extends AudioCache {
  _TemporaryAudioCache(this.tempDirectoryPath) : super();

  final String tempDirectoryPath;

  @override
  Future<String> getTempDir() async => tempDirectoryPath;
}

class _DelayedFirstAudioPromptOutput implements AudioPromptAudioOutput {
  final firstPlayStarted = Completer<void>();
  final firstPlayFinished = Completer<void>();
  final events = <String>[];
  var _playCount = 0;

  @override
  Future<void> playAsset(String assetPath) async {
    events.add('play:$assetPath');
    if (_playCount++ == 0) {
      firstPlayStarted.complete();
      await firstPlayFinished.future;
    }
  }

  @override
  Future<void> stop() async {
    events.add('stop');
  }

  @override
  Future<void> dispose() async {
    events.add('dispose');
  }
}

// Implements the plugin API without constructing a native AudioPlayer.
class _FakePluginAudioPlayer implements AudioPlayer {
  @override
  AudioCache audioCache = AudioCache(prefix: 'incorrect-prefix/');

  final sources = <Source>[];
  bool disposed = false;

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    sources.add(source);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

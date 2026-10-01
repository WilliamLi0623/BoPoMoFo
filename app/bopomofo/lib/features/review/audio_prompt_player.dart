import 'package:audioplayers/audioplayers.dart';

import 'audio_asset_manifest.dart';

abstract interface class AudioPromptPlayer {
  Future<void> play(String assetId);
  Future<void> dispose();
}

abstract interface class AudioPromptAudioOutput {
  /// Plays a path relative to the audio cache prefix (`assets/`).
  Future<void> playAsset(String assetPath);
  Future<void> stop();
  Future<void> dispose();
}

class AudioPromptPlaybackException implements Exception {
  const AudioPromptPlaybackException({
    required this.message,
    this.assetId,
    this.cause,
  });

  final String message;
  final String? assetId;
  final Object? cause;

  @override
  String toString() => 'AudioPromptPlaybackException: $message';
}

class OfflineAudioPromptPlayer implements AudioPromptPlayer {
  OfflineAudioPromptPlayer({
    required AudioAssetManifest manifest,
    AudioPromptAudioOutput? output,
  })  : _manifest = manifest,
        _output = output ?? AudioplayersAudioPromptOutput();

  static const _assetCachePrefix = 'assets/';

  final AudioAssetManifest _manifest;
  final AudioPromptAudioOutput _output;
  bool _hasActivePrompt = false;
  bool _isDisposed = false;
  Future<void> _operations = Future<void>.value();

  @override
  Future<void> play(String assetId) => _enqueue(() => _play(assetId));

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _operations.then((_) => operation());
    // A failed request reaches its caller without preventing the next request.
    _operations = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  Future<void> _play(String assetId) async {
    if (_isDisposed) {
      throw AudioPromptPlaybackException(
        message: 'The audio prompt player has been disposed.',
        assetId: assetId,
      );
    }

    final manifestPath = _manifest.assetPathForId(assetId);
    if (manifestPath == null) {
      throw AudioPromptPlaybackException(
        message: 'No bundled audio asset is registered for "$assetId".',
        assetId: assetId,
      );
    }

    final sourcePath = _sourcePathFor(manifestPath, assetId);
    try {
      if (_hasActivePrompt) {
        await _output.stop();
        _hasActivePrompt = false;
      }
      await _output.playAsset(sourcePath);
      _hasActivePrompt = true;
    } on AudioPromptPlaybackException {
      rethrow;
    } catch (error) {
      throw AudioPromptPlaybackException(
        message: 'Could not play bundled audio prompt "$assetId".',
        assetId: assetId,
        cause: error,
      );
    }
  }

  String _sourcePathFor(String manifestPath, String assetId) {
    if (!manifestPath.startsWith(_assetCachePrefix) ||
        manifestPath.startsWith('$_assetCachePrefix$_assetCachePrefix')) {
      throw AudioPromptPlaybackException(
        message: 'The bundled audio path is invalid: "$manifestPath".',
        assetId: assetId,
      );
    }
    return manifestPath.substring(_assetCachePrefix.length);
  }

  @override
  Future<void> dispose() => _enqueue(_dispose);

  Future<void> _dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    try {
      await _output.dispose();
    } catch (error) {
      throw AudioPromptPlaybackException(
        message: 'Could not dispose the audio prompt player.',
        cause: error,
      );
    }
  }
}

class AudioplayersAudioPromptOutput implements AudioPromptAudioOutput {
  AudioplayersAudioPromptOutput({AudioPlayer? player})
      : _player = player ?? AudioPlayer() {
    _player.audioCache =
        AudioCache(prefix: OfflineAudioPromptPlayer._assetCachePrefix);
  }

  final AudioPlayer _player;

  @override
  Future<void> playAsset(String assetPath) =>
      _player.play(AssetSource(assetPath));

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

import 'dart:convert';

import 'package:flutter/services.dart';

class AudioAssetEntry {
  const AudioAssetEntry({
    required this.id,
    required this.pinyin,
    required this.expectedAnswer,
    required this.assetPath,
    required this.sourceArchiveEntry,
    required this.attribution,
    required this.sourceUrl,
    required this.license,
  });

  final String id;
  final String pinyin;
  final String expectedAnswer;
  final String assetPath;
  final String sourceArchiveEntry;
  final String attribution;
  final String sourceUrl;
  final String license;

  factory AudioAssetEntry.fromJson(Map<String, dynamic> json) {
    return AudioAssetEntry(
      id: json['id'] as String,
      pinyin: json['pinyin'] as String,
      expectedAnswer: json['expectedAnswer'] as String,
      assetPath: json['assetPath'] as String,
      sourceArchiveEntry: json['sourceArchiveEntry'] as String,
      attribution: json['attribution'] as String,
      sourceUrl: json['sourceUrl'] as String,
      license: json['license'] as String,
    );
  }
}

class AudioAssetManifest {
  const AudioAssetManifest(this.entries);

  final List<AudioAssetEntry> entries;

  String? assetPathForId(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry.assetPath;
    }
    return null;
  }

  static Future<AudioAssetManifest> loadBundled(AssetBundle bundle) async {
    final manifest = await load(bundle);
    final assets = (await AssetManifest.loadFromAssetBundle(bundle)).listAssets().toSet();
    return AudioAssetManifest(List.unmodifiable(
      manifest.entries.where((entry) => assets.contains(entry.assetPath)),
    ));
  }

  static Future<AudioAssetManifest> load(AssetBundle bundle) async {
    final contents = await bundle.loadString('assets/audio/manifest.json');
    final json = jsonDecode(contents) as Map<String, dynamic>;
    final entries = (json['entries'] as List<dynamic>)
        .map((entry) => AudioAssetEntry.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
    return AudioAssetManifest(entries);
  }
}

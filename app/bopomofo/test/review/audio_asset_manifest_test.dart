import 'package:bopomofo/features/review/audio_asset_manifest.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('audio manifest resolves only licensed mapped bundled assets', () async {
    final manifest = await AudioAssetManifest.load(rootBundle);
    final entries = manifest.entries;

    const verifiedMappings = {
      'ba': 'ㄅㄚ', 'ma': 'ㄇㄚ', 'bi': 'ㄅㄧ',
      'bu': 'ㄅㄨ', 'da': 'ㄉㄚ', 'na': 'ㄋㄚ',
      'he': 'ㄏㄜ', 'ta': 'ㄊㄚ', 'ji': 'ㄐㄧ',
      'xi': 'ㄒㄧ', 'bai': 'ㄅㄞ', 'bao': 'ㄅㄠ',
    };
    expect(entries, hasLength(verifiedMappings.length));
    expect(entries.map((entry) => entry.id).toSet(), hasLength(entries.length));
    expect(
      {for (final entry in entries) entry.pinyin: entry.expectedAnswer},
      verifiedMappings,
    );

    for (final entry in entries) {
      expect(verifiedMappings.containsKey(entry.pinyin), isTrue,
          reason: 'Unverified pinyin: ${entry.pinyin}');
      expect(entry.expectedAnswer, verifiedMappings[entry.pinyin]);
      expect(entry.sourceArchiveEntry, isNotEmpty);
      expect(entry.expectedAnswer, isNotEmpty);
      expect(entry.attribution, contains('Ministry of Digital Affairs'));
      expect(entry.attribution, contains('CNS11643'));
      expect(entry.sourceUrl, 'https://www.cns11643.gov.tw/opendata/Voice.zip');
      expect(entry.license, 'Government Open Data License, Version 1.0');
      expect(entry.assetPath, startsWith('assets/audio/'));
      expect(await rootBundle.load(entry.assetPath), isNotNull);
    }
  });

  test('stable audio IDs resolve to packaged paths', () async {
    final manifest = await AudioAssetManifest.load(rootBundle);

    expect(
        manifest.assetPathForId('cns11643-female-ba'), 'assets/audio/F_ba.mp3');
    expect(
        manifest.assetPathForId('cns11643-female-ma'), 'assets/audio/F_ma.mp3');
    expect(manifest.assetPathForId('unknown-id'), isNull);
  });
}

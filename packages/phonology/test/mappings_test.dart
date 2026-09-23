import 'package:test/test.dart';

import 'package:phonology/phonology.dart';

void main() {
  test('converts required pinyin mappings', () {
    expect(toZhuyin('ma'), 'ㄇㄚ');
    expect(toZhuyin('zhong'), 'ㄓㄨㄥ');
    expect(toZhuyin('zhi'), 'ㄓ');
    expect(toZhuyin('shi'), 'ㄕ');
    expect(toZhuyin('ju'), 'ㄐㄩ');
  });

  test('exposes all 37 symbols with stable keyboard keys', () {
    expect(symbols, hasLength(37));
    expect(symbols.map((symbol) => symbol.id).toSet(), hasLength(37));
    expect(symbols.map((symbol) => symbol.keyboardKey).toSet(), hasLength(37));

    final keyboardByGlyph = {
      'ㄅ': '1', 'ㄆ': 'q', 'ㄇ': 'a', 'ㄈ': 'z',
      'ㄉ': '2', 'ㄊ': 'w', 'ㄋ': 's', 'ㄌ': 'x',
      'ㄍ': 'e', 'ㄎ': 'd', 'ㄏ': 'c', 'ㄐ': 'r',
      'ㄑ': 'f', 'ㄒ': 'v', 'ㄓ': '5', 'ㄔ': 't',
      'ㄕ': 'g', 'ㄖ': 'b', 'ㄗ': 'y', 'ㄘ': 'h',
      'ㄙ': 'n', 'ㄧ': 'u', 'ㄨ': 'j', 'ㄩ': 'm',
      'ㄚ': '8', 'ㄛ': 'i', 'ㄜ': 'k', 'ㄝ': ',',
      'ㄞ': '9', 'ㄟ': 'o', 'ㄠ': 'l', 'ㄡ': '.',
      'ㄢ': '0', 'ㄣ': 'p', 'ㄤ': ';', 'ㄥ': '/', 'ㄦ': '-',
    };
    expect({
      for (final symbol in symbols) symbol.glyph: symbol.keyboardKey,
    }, keyboardByGlyph);
  });

  test('reports every required member of every trap family', () {
    expect(trapFor('shi').expected, 'ㄕ');
    expect(
      trapFamilies[0].map((trap) => '${trap.input}:${trap.expected}'),
      containsAll(['zhi:ㄓ', 'chi:ㄔ', 'shi:ㄕ', 'ri:ㄖ']),
    );
    expect(
      trapFamilies[1].map((trap) => '${trap.input}:${trap.expected}'),
      containsAll(['zi:ㄗ', 'ci:ㄘ', 'si:ㄙ']),
    );
    expect(
      trapFamilies[2].map((trap) => '${trap.input}:${trap.expected}'),
      containsAll(['ju:ㄐㄩ', 'qu:ㄑㄩ', 'xu:ㄒㄩ']),
    );
    expect(
      trapFamilies[3].map((trap) => '${trap.input}:${trap.expected}'),
      containsAll(['yi:ㄧ', 'wu:ㄨ', 'yu:ㄩ']),
    );
    expect(
      trapFamilies[4].map((trap) => '${trap.input}:${trap.expected}'),
      containsAll(['you:ㄧㄡ', 'wei:ㄨㄟ', 'wen:ㄨㄣ', 'yong:ㄩㄥ']),
    );
  });

  test('unknown pinyin is a typed conversion error', () {
    expect(() => toZhuyin('not-a-syllable'), throwsA(isA<UnknownPinyinError>()));
  });
}

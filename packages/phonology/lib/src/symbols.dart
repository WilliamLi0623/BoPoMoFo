import 'package:domain/domain.dart';

const _definitions = <(String, String, String, String?, String)>[
  ('b', 'ㄅ', 'initial', 'b', '1'), ('p', 'ㄆ', 'initial', 'p', 'q'),
  ('m', 'ㄇ', 'initial', 'm', 'a'), ('f', 'ㄈ', 'initial', 'f', 'z'),
  ('d', 'ㄉ', 'initial', 'd', '2'), ('t', 'ㄊ', 'initial', 't', 'w'),
  ('n', 'ㄋ', 'initial', 'n', 's'), ('l', 'ㄌ', 'initial', 'l', 'x'),
  ('g', 'ㄍ', 'initial', 'g', 'e'), ('k', 'ㄎ', 'initial', 'k', 'd'),
  ('h', 'ㄏ', 'initial', 'h', 'c'), ('j', 'ㄐ', 'initial', 'j', 'r'),
  ('q', 'ㄑ', 'initial', 'q', 'f'), ('x', 'ㄒ', 'initial', 'x', 'v'),
  ('zh', 'ㄓ', 'initial', 'zh', '5'), ('ch', 'ㄔ', 'initial', 'ch', 't'),
  ('sh', 'ㄕ', 'initial', 'sh', 'g'), ('r', 'ㄖ', 'initial', 'r', 'b'),
  ('z', 'ㄗ', 'initial', 'z', 'y'), ('c', 'ㄘ', 'initial', 'c', 'h'),
  ('s', 'ㄙ', 'initial', 's', 'n'), ('a', 'ㄚ', 'final', 'a', '8'),
  ('o', 'ㄛ', 'final', 'o', 'i'), ('e', 'ㄜ', 'final', 'e', 'k'),
  ('ê', 'ㄝ', 'final', 'ê', ','), ('ai', 'ㄞ', 'final', 'ai', '9'),
  ('ei', 'ㄟ', 'final', 'ei', 'o'), ('ao', 'ㄠ', 'final', 'ao', 'l'),
  ('ou', 'ㄡ', 'final', 'ou', '.'), ('an', 'ㄢ', 'final', 'an', '0'),
  ('en', 'ㄣ', 'final', 'en', 'p'), ('ang', 'ㄤ', 'final', 'ang', ';'),
  ('eng', 'ㄥ', 'final', 'eng', '/'), ('er', 'ㄦ', 'final', 'er', '-'),
  ('i', 'ㄧ', 'medial', 'i', 'u'), ('u', 'ㄨ', 'medial', 'u', 'j'),
  ('ü', 'ㄩ', 'medial', 'ü', 'm'),
];

final List<Symbol> symbols = List.unmodifiable(
  _definitions
      .map((definition) => Symbol(
            id: definition.$1,
            glyph: definition.$2,
            category: definition.$3,
            pinyin: definition.$4,
            keyboardKey: definition.$5,
          ))
      .toList(),
);

const tones = <int>[1, 2, 3, 4, 5];

final initials = List<Symbol>.unmodifiable(
  symbols.where((symbol) => symbol.category == 'initial'),
);
final medials = List<Symbol>.unmodifiable(
  symbols.where((symbol) => symbol.category == 'medial'),
);
final finals = List<Symbol>.unmodifiable(
  symbols.where((symbol) => symbol.category == 'final'),
);

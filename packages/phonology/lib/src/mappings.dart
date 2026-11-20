class UnknownPinyinError extends FormatException {
  UnknownPinyinError(String input) : super('Unknown pinyin syllable: $input');
}

const _mapping = <String, String>{
  'ma': 'ㄇㄚ', 'zhong': 'ㄓㄨㄥ', 'zhi': 'ㄓ', 'shi': 'ㄕ',
  'ju': 'ㄐㄩ', 'chi': 'ㄔ', 'ri': 'ㄖ', 'zi': 'ㄗ', 'ci': 'ㄘ',
  'si': 'ㄙ', 'qu': 'ㄑㄩ', 'xu': 'ㄒㄩ', 'yi': 'ㄧ', 'wu': 'ㄨ',
  'yu': 'ㄩ', 'you': 'ㄧㄡ', 'wei': 'ㄨㄟ', 'wen': 'ㄨㄣ', 'yong': 'ㄩㄥ',
  'ba': 'ㄅㄚ', 'bo': 'ㄅㄛ', 'bi': 'ㄅㄧ', 'bu': 'ㄅㄨ',
  'pa': 'ㄆㄚ', 'fa': 'ㄈㄚ',
  'da': 'ㄉㄚ', 'de': 'ㄉㄜ', 'di': 'ㄉㄧ', 'du': 'ㄉㄨ',
  'ga': 'ㄍㄚ', 'ge': 'ㄍㄜ', 'gu': 'ㄍㄨ', 'ka': 'ㄎㄚ',
  'la': 'ㄌㄚ', 'le': 'ㄌㄜ', 'li': 'ㄌㄧ', 'lu': 'ㄌㄨ',
  'na': 'ㄋㄚ', 'ne': 'ㄋㄜ', 'ni': 'ㄋㄧ', 'nu': 'ㄋㄨ',
  // Course syllables added so guided lessons reach every zhuyin symbol
  // (see LearningLesson examples in app/bopomofo).
  'ta': 'ㄊㄚ', 'te': 'ㄊㄜ', 'he': 'ㄏㄜ',
  'ji': 'ㄐㄧ', 'qi': 'ㄑㄧ', 'xi': 'ㄒㄧ',
  'bai': 'ㄅㄞ', 'bei': 'ㄅㄟ', 'bao': 'ㄅㄠ', 'dou': 'ㄉㄡ',
  'ban': 'ㄅㄢ', 'ben': 'ㄅㄣ', 'bang': 'ㄅㄤ', 'deng': 'ㄉㄥ',
  'er': 'ㄦ', 'ye': 'ㄧㄝ',
};

String toZhuyin(String pinyin) {
  final key = pinyin.trim().toLowerCase();
  final result = _mapping[key];
  if (result == null) throw UnknownPinyinError(pinyin);
  return result;
}

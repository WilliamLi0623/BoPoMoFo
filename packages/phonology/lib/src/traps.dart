class TrapCase {
  final String input;
  final String expected;
  final String explanation;

  const TrapCase(this.input, this.expected, this.explanation);
}

const trapFamilies = <List<TrapCase>>[
  [TrapCase('zhi', 'ㄓ', 'retroflex apical vowel is implicit'), TrapCase('chi', 'ㄔ', 'retroflex apical vowel is implicit'), TrapCase('shi', 'ㄕ', 'retroflex apical vowel is implicit'), TrapCase('ri', 'ㄖ', 'retroflex apical vowel is implicit')],
  [TrapCase('zi', 'ㄗ', 'dental apical vowel is implicit'), TrapCase('ci', 'ㄘ', 'dental apical vowel is implicit'), TrapCase('si', 'ㄙ', 'dental apical vowel is implicit')],
  [TrapCase('ju', 'ㄐㄩ', 'ü is written u after j'), TrapCase('qu', 'ㄑㄩ', 'ü is written u after q'), TrapCase('xu', 'ㄒㄩ', 'ü is written u after x')],
  [TrapCase('yi', 'ㄧ', 'y is an orthographic glide'), TrapCase('wu', 'ㄨ', 'w is an orthographic glide'), TrapCase('yu', 'ㄩ', 'y marks ü')],
  [TrapCase('you', 'ㄧㄡ', 'youn begins with ㄧ'), TrapCase('wei', 'ㄨㄟ', 'wei begins with ㄨ'), TrapCase('wen', 'ㄨㄣ', 'wen begins with ㄨ'), TrapCase('yong', 'ㄩㄥ', 'yong begins with ㄩ')],
];

TrapCase trapFor(String pinyin) {
  for (final family in trapFamilies) {
    for (final trap in family) {
      if (trap.input == pinyin.toLowerCase()) return trap;
    }
  }
  throw ArgumentError.value(pinyin, 'pinyin', 'not an explicit trap case');
}

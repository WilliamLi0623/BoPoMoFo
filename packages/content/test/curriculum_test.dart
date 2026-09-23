import 'package:test/test.dart';

import 'package:content/content.dart';

void main() {
  test('curriculum units are ordered and deterministic', () {
    final first = defaultCurriculum;
    final second = Curriculum.fromMap(first.toMap());

    expect(first.units.map((unit) => unit.id).toList(), [
      'mapping',
      'conversion',
      'trap-practice',
      'pinyin-fade',
      'word-recognition',
      'keyboard-discovery',
      'typing',
    ]);
    expect(second.toMap(), first.toMap());
  });

  test('unit requiring ㄅ and ㄚ stays locked until both pass', () {
    final unit = defaultCurriculum.unit('conversion');

    expect(unit.isUnlocked({}), isFalse);
    expect(unit.isUnlocked({'ㄅ': 0.79, 'ㄚ': 1.0}), isFalse);
    expect(unit.isUnlocked({'ㄅ': 0.8, 'ㄚ': 0.79}), isFalse);
    expect(unit.isUnlocked({'ㄅ': 0.8, 'ㄚ': 0.8}), isTrue);
  });

  test('curriculum defensively copies constructor inputs', () {
    final source = <CurriculumUnit>[
      CurriculumUnit(id: 'source', order: 1),
    ];
    final curriculum = Curriculum(source);
    source.clear();

    expect(curriculum.units.map((unit) => unit.id), ['source']);
    expect(() => curriculum.units.add(CurriculumUnit(id: 'x', order: 2)),
        throwsUnsupportedError);
  });

  test('curriculum units defensively copy list inputs', () {
    final prerequisites = <String>['ㄅ'];
    final lessons = <LessonContent>[
      const LessonContent(id: 'lesson', prompt: 'ㄅ', answer: 'b'),
    ];
    final unit = CurriculumUnit(
      id: 'unit',
      order: 1,
      prerequisites: prerequisites,
      lessons: lessons,
    );
    prerequisites.clear();
    lessons.clear();

    expect(unit.prerequisites, ['ㄅ']);
    expect(unit.lessons, hasLength(1));
    expect(() => unit.prerequisites.add('ㄚ'), throwsUnsupportedError);
    expect(() => unit.lessons.add(
          const LessonContent(id: 'x', prompt: 'x', answer: 'x'),
        ), throwsUnsupportedError);
  });
}

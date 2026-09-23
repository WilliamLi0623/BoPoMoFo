import 'lesson_content.dart';

class CurriculumUnit {
  final String id;
  final int order;
  final List<String> prerequisites;
  final double threshold;
  final List<LessonContent> lessons;

  CurriculumUnit({
    required this.id,
    required this.order,
    List<String> prerequisites = const [],
    this.threshold = 0.8,
    List<LessonContent> lessons = const [],
  })  : prerequisites = List<String>.unmodifiable(prerequisites),
        lessons = List<LessonContent>.unmodifiable(lessons);

  bool isUnlocked(Map<String, double> passedScores) => prerequisites.every(
        (itemId) => (passedScores[itemId] ?? 0) >= threshold,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'order': order,
        'prerequisites': prerequisites,
        'threshold': threshold,
        'lessons': lessons.map((lesson) => lesson.toMap()).toList(),
      };

  factory CurriculumUnit.fromMap(Map<String, Object?> map) => CurriculumUnit(
        id: map['id']! as String,
        order: map['order']! as int,
        prerequisites: List<String>.from(map['prerequisites']! as List),
        threshold: (map['threshold']! as num).toDouble(),
        lessons: (map['lessons']! as List)
            .map((lesson) => LessonContent.fromMap(
                  Map<String, Object?>.from(lesson as Map),
                ))
            .toList(growable: false),
      );
}

class Curriculum {
  final List<CurriculumUnit> units;

  Curriculum(List<CurriculumUnit> units)
      : units = List<CurriculumUnit>.unmodifiable(units);

  CurriculumUnit unit(String id) => units.firstWhere((unit) => unit.id == id);

  Map<String, Object?> toMap() => {
        'units': units.map((unit) => unit.toMap()).toList(),
      };

  factory Curriculum.fromMap(Map<String, Object?> map) => Curriculum(
        (map['units']! as List)
            .map((unit) => CurriculumUnit.fromMap(
                  Map<String, Object?>.from(unit as Map),
                ))
            .toList(growable: false),
      );
}

final defaultCurriculum = Curriculum([
  CurriculumUnit(id: 'mapping', order: 1),
  CurriculumUnit(
    id: 'conversion',
    order: 2,
    prerequisites: ['ㄅ', 'ㄚ'],
  ),
  CurriculumUnit(id: 'trap-practice', order: 3),
  CurriculumUnit(id: 'pinyin-fade', order: 4),
  CurriculumUnit(id: 'word-recognition', order: 5),
  CurriculumUnit(id: 'keyboard-discovery', order: 6),
  CurriculumUnit(id: 'typing', order: 7),
]);

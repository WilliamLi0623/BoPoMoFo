import 'package:domain/domain.dart';

class MasteryKey {
  final String itemId;
  final Skill skill;

  const MasteryKey(this.itemId, this.skill);

  @override
  bool operator ==(Object other) =>
      other is MasteryKey && other.itemId == itemId && other.skill == skill;

  @override
  int get hashCode => Object.hash(itemId, skill);
}

class MasteryRecord {
  final MasteryKey key;
  final double mastery;
  final double stability;
  final int attempts;

  const MasteryRecord({required this.key, required this.mastery, required this.stability, required this.attempts});
}

class MasteryStore {
  final Map<MasteryKey, MasteryRecord> _records = {};

  void record(String itemId, Skill skill, {required bool correct, required double stability}) {
    final key = MasteryKey(itemId, skill);
    final previous = _records[key];
    final attempts = (previous?.attempts ?? 0) + 1;
    final mastery = ((previous?.mastery ?? 0) * (attempts - 1) + (correct ? 1 : 0)) / attempts;
    _records[key] = MasteryRecord(
      key: key,
      mastery: mastery,
      stability: stability,
      attempts: attempts,
    );
  }

  double valueFor(String itemId, Skill skill) => _records[MasteryKey(itemId, skill)]?.mastery ?? 0;

  MasteryRecord? recordFor(String itemId, Skill skill) => _records[MasteryKey(itemId, skill)];
}

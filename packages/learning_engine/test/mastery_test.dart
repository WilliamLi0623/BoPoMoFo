import 'package:test/test.dart';

import 'package:learning_engine/learning_engine.dart';
import 'package:domain/domain.dart';

void main() {
  test('mastery is independent for each item and skill', () {
    final store = MasteryStore();
    store.record('ㄓ', Skill.recognition, correct: true, stability: 10);

    expect(store.valueFor('ㄓ', Skill.recognition), greaterThan(0));
    expect(store.valueFor('ㄓ', Skill.keyboard), 0);
  });

  test('smart fade requires mastery for the relevant skill', () {
    final recognition = ReviewState(
      itemId: 'ㄓ', skill: Skill.recognition, difficulty: 5,
      stability: 25, dueAt: DateTime.utc(2026), reps: 3,
    );
    final mastery = MasteryStore();

    expect(pinyinSupportFor(recognition, mastery), 1.0);

    mastery.record('ㄓ', Skill.keyboard, correct: true, stability: 25);
    expect(pinyinSupportFor(recognition, mastery), 1.0);

    mastery.record('ㄓ', Skill.recognition, correct: true, stability: 25);
    expect(pinyinSupportFor(recognition, mastery), 0.0);
  });

  test('smart fade uses exact mastery and stability bands', () {
    final state = ReviewState(
      itemId: 'ㄓ', skill: Skill.recognition, difficulty: 5,
      stability: 11, dueAt: DateTime.utc(2026), reps: 3,
    );
    final mastery = MasteryStore();
    mastery.record('ㄓ', Skill.recognition, correct: true, stability: 11);

    expect(pinyinSupportFor(state.copyWith(stability: 3), mastery), 0.7);
    expect(pinyinSupportFor(state, mastery), 0.3);
    expect(pinyinSupportFor(state.copyWith(stability: 25), mastery), 0.0);
  });
}

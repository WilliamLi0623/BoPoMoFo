import 'package:domain/domain.dart';
import 'mastery.dart';

extension ReviewStateCopy on ReviewState {
  ReviewState copyWith({double? stability, Skill? skill}) => ReviewState(
        itemId: itemId,
        skill: skill ?? this.skill,
        difficulty: difficulty,
        stability: stability ?? this.stability,
        lastReviewAt: lastReviewAt,
        dueAt: dueAt,
        reps: reps,
      );
}

double pinyinSupportFor(ReviewState state, MasteryStore masteryStore) {
  final mastery = masteryStore.valueFor(state.itemId, state.skill);
  if (mastery < 0.8) return 1.0;
  if (state.stability >= 21 && mastery >= 0.95 && state.reps >= 3) return 0.0;
  if (state.stability >= 10 && mastery >= 0.9 && state.reps >= 2) return 0.3;
  if (state.stability >= 3 && mastery >= 0.8 && state.reps >= 1) return 0.7;
  return 1.0;
}

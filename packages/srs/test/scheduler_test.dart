import 'package:test/test.dart';

import 'package:srs/srs.dart';
import 'package:domain/domain.dart';

void main() {
  final now = DateTime.utc(2026, 9, 22, 12);

  ReviewState initial() => ReviewState(
        itemId: 'ㄓ',
        skill: Skill.recognition,
        difficulty: 5,
        stability: 1,
        dueAt: now,
        reps: 1,
      );

  test('scheduler is deterministic for the same state, rating, and time', () {
    final scheduler = FsrsScheduler();

    final first = scheduler.schedule(initial(), ReviewRating.good, now);
    final second = scheduler.schedule(initial(), ReviewRating.good, now);

    expect(first.dueAt, second.dueAt);
    expect(first.stability, second.stability);
    expect(first.difficulty, second.difficulty);
    expect((first as FsrsReviewState).algorithmVersion, algorithmVersion);
  });

  test('again is earlier than good and easy grows stability more than hard', () {
    final scheduler = FsrsScheduler();
    final again = scheduler.schedule(initial(), ReviewRating.again, now);
    final good = scheduler.schedule(initial(), ReviewRating.good, now);
    final hard = scheduler.schedule(initial(), ReviewRating.hard, now);
    final easy = scheduler.schedule(initial(), ReviewRating.easy, now);

    expect(again.dueAt.isBefore(good.dueAt), isTrue);
    expect(easy.stability, greaterThan(hard.stability));
  });

  test('scheduler preserves an input algorithm version', () {
    final scheduler = FsrsScheduler();
    final versioned = FsrsReviewState(
      itemId: 'ㄓ', skill: Skill.recognition, difficulty: 5,
      stability: 1, dueAt: now, reps: 1, algorithmVersion: 'fsrs-lite-0',
    );

    final result = scheduler.schedule(versioned, ReviewRating.good, now);

    expect((result as FsrsReviewState).algorithmVersion, 'fsrs-lite-0');
  });
}

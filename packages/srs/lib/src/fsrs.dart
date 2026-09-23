import 'package:domain/domain.dart';

const algorithmVersion = 'fsrs-lite-1';

class FsrsReviewState extends ReviewState {
  final String algorithmVersion;

  FsrsReviewState({
    required super.itemId,
    required super.skill,
    required super.difficulty,
    required super.stability,
    super.lastReviewAt,
    required super.dueAt,
    required super.reps,
    this.algorithmVersion = 'fsrs-lite-1',
  });

  FsrsReviewState.from(ReviewState state, {
    required this.algorithmVersion,
  }) : super(
          itemId: state.itemId,
          skill: state.skill,
          difficulty: state.difficulty,
          stability: state.stability,
          lastReviewAt: state.lastReviewAt,
          dueAt: state.dueAt,
          reps: state.reps,
        );
}

double _clamp(double value, double min, double max) =>
    value.clamp(min, max).toDouble();

FsrsReviewState transition(
  ReviewState state,
  ReviewRating rating,
  DateTime now,
) {
  final version = state is FsrsReviewState
      ? state.algorithmVersion
      : algorithmVersion;
  final multiplier = switch (rating) {
    ReviewRating.again => 0.35,
    ReviewRating.hard => 0.85,
    ReviewRating.good => 1.0,
    ReviewRating.easy => 1.35,
  };
  final stability = rating == ReviewRating.again
      ? 0.1
      : _clamp(state.stability * multiplier + (rating == ReviewRating.easy ? 0.5 : 0.2), 0.1, 3650);
  final difficulty = _clamp(
    state.difficulty + switch (rating) {
      ReviewRating.again => 0.3,
      ReviewRating.hard => 0.1,
      ReviewRating.good => -0.05,
      ReviewRating.easy => -0.2,
    },
    1,
    10,
  );
  final intervalDays = switch (rating) {
    ReviewRating.again => 10 / (24 * 60),
    ReviewRating.hard => stability * 0.7,
    ReviewRating.good => stability,
    ReviewRating.easy => stability * 1.5,
  };

  return FsrsReviewState(
    itemId: state.itemId,
    skill: state.skill,
    difficulty: difficulty,
    stability: stability,
    lastReviewAt: now,
    dueAt: now.add(Duration(microseconds: (intervalDays * Duration.microsecondsPerDay).round())),
    reps: state.reps + 1,
    algorithmVersion: version,
  );
}

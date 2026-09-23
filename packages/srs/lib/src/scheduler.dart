import 'package:domain/domain.dart';
import 'fsrs.dart';

abstract interface class Scheduler {
  ReviewState schedule(ReviewState state, ReviewRating rating, DateTime now);
}

class FsrsScheduler implements Scheduler {
  const FsrsScheduler();

  @override
  ReviewState schedule(ReviewState state, ReviewRating rating, DateTime now) =>
      transition(state, rating, now);
}

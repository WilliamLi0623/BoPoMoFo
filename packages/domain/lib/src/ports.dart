import 'entities.dart';

abstract interface class LearningRepository {
  Future<void> recordReview(ReviewAttempt attempt);
  Stream<DashboardSnapshot> watchDashboard();
}

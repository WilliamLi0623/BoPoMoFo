import 'package:domain/domain.dart';
import 'package:learning_engine/learning_engine.dart';
import 'package:srs/srs.dart';

import '../database.dart';

class ProjectionsDao {
  final LocalDatabase database;

  const ProjectionsDao(this.database);

  Future<void> clear() async {
    await database.execute('DELETE FROM review_projections');
    await database.execute('DELETE FROM confusion_edges');
  }

  Future<void> saveReview(ReviewState state) async {
    final algorithm = state is FsrsReviewState ? state.algorithmVersion : algorithmVersion;
    await database.execute('''
      INSERT INTO review_projections
      (item_id, skill, difficulty, stability, last_review_at, due_at, reps, algorithm_version)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(item_id, skill) DO UPDATE SET
        difficulty = excluded.difficulty,
        stability = excluded.stability,
        last_review_at = excluded.last_review_at,
        due_at = excluded.due_at,
        reps = excluded.reps,
        algorithm_version = excluded.algorithm_version
    ''', [
      state.itemId,
      state.skill.name,
      state.difficulty,
      state.stability,
      state.lastReviewAt?.toUtc().toIso8601String(),
      state.dueAt.toUtc().toIso8601String(),
      state.reps,
      algorithm,
    ]);
  }

  Future<void> saveConfusion({
    required String expected,
    required String response,
    required bool error,
  }) async {
    final key = '$expected->$response';
    await database.execute('''
      INSERT INTO confusion_edges (edge_key, expected, response, exposure_count, error_count)
      VALUES (?, ?, ?, 1, ?)
      ON CONFLICT(edge_key) DO UPDATE SET
        exposure_count = exposure_count + 1,
        error_count = error_count + excluded.error_count
    ''', [key, expected, response, error ? 1 : 0]);
  }

  Future<LearningSnapshot> snapshot() async {
    final reviewRows = await database.select(
      'SELECT * FROM review_projections ORDER BY item_id ASC, skill ASC',
    );
    final confusionRows = await database.select('''
      SELECT * FROM confusion_edges
      WHERE exposure_count >= 2 AND error_count > 0
      ORDER BY (CAST(error_count AS REAL) / exposure_count) DESC, edge_key ASC
    ''');
    return LearningSnapshot(
      reviewStates: reviewRows.map(_reviewFromRow).toList(growable: false),
      confusionTargets: confusionRows
          .map((row) => ConfusionTarget(
                expected: row['expected']! as String,
                response: row['response']! as String,
                errorRate: (row['error_count']! as num) /
                    (row['exposure_count']! as num),
                exposureCount: row['exposure_count']! as int,
                errorCount: row['error_count']! as int,
              ))
          .toList(growable: false),
    );
  }

  static ReviewState _reviewFromRow(Map<String, Object?> row) => FsrsReviewState(
        itemId: row['item_id']! as String,
        skill: Skill.values.byName(row['skill']! as String),
        difficulty: (row['difficulty']! as num).toDouble(),
        stability: (row['stability']! as num).toDouble(),
        lastReviewAt: row['last_review_at'] == null
            ? null
            : DateTime.parse(row['last_review_at']! as String),
        dueAt: DateTime.parse(row['due_at']! as String),
        reps: row['reps']! as int,
        algorithmVersion: row['algorithm_version']! as String,
      );
}

import 'package:material_ui/material_ui.dart';
import '../../bootstrap.dart';
import '../../l10n/app_localizations.dart';

class LessonPage extends StatelessWidget {
  const LessonPage({required this.learningEngine, required this.repository, required this.path, required this.onReview, super.key});

  final LearningEngine learningEngine;
  final AppLearningRepository repository;
  final String path;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final labels = AppLocalizations.of(context)!;
    return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(labels.lessonTitle, style: Theme.of(context).textTheme.headlineMedium),
          Text(labels.lessonStarted),
          const SizedBox(height: 12),
          Text(switch (path) {
            'sounds' => labels.lessonPathSounds,
            'beginner' => labels.lessonPathBeginner,
            _ => labels.lessonPathPinyin,
          }),
          const SizedBox(height: 24),
          Card(child: ListTile(title: Text(labels.lessonToday('ㄅ')), subtitle: Text(labels.lessonRecognitionMapping))),
          const SizedBox(height: 16),
          FilledButton(onPressed: onReview, child: Text(labels.reviewDueItems)),
        ],
      );
  }
}

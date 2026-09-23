import 'package:flutter/material.dart';
import '../../bootstrap.dart';

class LessonPage extends StatelessWidget {
  const LessonPage({required this.learningEngine, required this.repository, required this.path, required this.onReview, super.key});

  final LearningEngine learningEngine;
  final AppLearningRepository repository;
  final String path;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Your first lesson', style: Theme.of(context).textTheme.headlineMedium),
          const Text('Learning started'),
          const SizedBox(height: 12),
          Text(switch (path) {
            'sounds' => 'Listen for the shape and sound of each symbol.',
            'beginner' => 'Build a clear foundation one symbol at a time.',
            _ => 'Use your Pinyin knowledge as a bridge to Zhuyin.',
          }),
          const SizedBox(height: 24),
          const Card(child: ListTile(title: Text('Today: ㄅ'), subtitle: Text('Recognition · direct mapping'))),
          const SizedBox(height: 16),
          FilledButton(onPressed: onReview, child: const Text('Review due items')),
        ],
      );
}

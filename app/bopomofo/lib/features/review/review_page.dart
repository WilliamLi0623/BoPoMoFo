import 'package:flutter/material.dart';
import 'package:domain/domain.dart';

import '../../bootstrap.dart';
import '../../l10n/app_localizations.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({required this.repository, super.key});

  final AppLearningRepository repository;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  bool _saved = false;

  Future<void> _answer(bool correct) async {
    await widget.repository.recordReview(ReviewAttempt(
      itemId: 'ㄅ',
      skill: Skill.recognition,
      correct: correct,
      occurredAt: DateTime.now().toUtc(),
    ));
    if (mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final labels = AppLocalizations.of(context)!;
    return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(labels.reviewTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          Text(labels.reviewQuestion, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          Text('ㄅ', key: const ValueKey('review-prompt-ㄅ'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 24),
          Wrap(spacing: 12, runSpacing: 12, children: [
            FilledButton(key: const ValueKey('review-answer-correct'), onPressed: () => _answer(true), child: const Text('ㄅ')),
            OutlinedButton(key: const ValueKey('review-answer-wrong'), onPressed: () => _answer(false), child: const Text('ㄆ')),
          ]),
          if (_saved) ...[
            const SizedBox(height: 20),
            Card(child: ListTile(leading: const Icon(Icons.check_circle), title: Text(labels.reviewSavedLocally), subtitle: Text(labels.reviewOfflineProgress))),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => setState(() => _saved = false), child: Text(labels.reviewNextPrompt)),
          ],
        ],
      );
  }
}

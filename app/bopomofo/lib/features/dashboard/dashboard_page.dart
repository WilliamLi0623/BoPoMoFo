import 'package:flutter/material.dart';
import 'package:domain/domain.dart';

import '../../bootstrap.dart';
import '../../l10n/app_localizations.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.learningEngine, required this.repository, super.key});

  final LearningEngine learningEngine;
  final AppLearningRepository repository;

  @override
  Widget build(BuildContext context) {
    final labels = AppLocalizations.of(context)!;
    return StreamBuilder<DashboardSnapshot>(
        stream: repository.watchDashboard(),
        initialData: repository.dashboard,
        builder: (context, snapshot) {
          final data = snapshot.data ?? repository.dashboard;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(labels.dashboardProgress, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _MasteryCard(labels.masteryRecognition, Skill.recognition, repository),
                _MasteryCard(labels.masteryListening, Skill.listening, repository),
                _MasteryCard(labels.masteryPinyinConversion, Skill.pinyinConversion, repository),
                _MasteryCard(labels.masteryKeyboard, Skill.keyboard, repository),
                _MasteryCard(labels.masteryHanziInput, Skill.composition, repository),
              ]),
              const SizedBox(height: 20),
              Card(child: ListTile(title: Text(labels.dueReviewsCount(data.dueCount)), subtitle: Text(labels.masteredItemsCount(data.masteredCount)))),
              Card(child: ListTile(title: Text(labels.confusionTargetsCount(0)), subtitle: Text(labels.confusionHint))),
            ],
          );
        },
      );
  }
}

class _MasteryCard extends StatelessWidget {
  const _MasteryCard(this.label, this.skill, this.repository);

  final String label;
  final Skill skill;
  final AppLearningRepository repository;

  @override
  Widget build(BuildContext context) {
    final labels = AppLocalizations.of(context)!;
    return SizedBox(
        width: 180,
        child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), const SizedBox(height: 8), Text(labels.masteryPercent((repository.masteryFor(skill) * 100).round()), style: Theme.of(context).textTheme.titleLarge)]))),
      );
  }
}

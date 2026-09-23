import 'package:flutter/material.dart';
import 'package:domain/domain.dart';

import '../../bootstrap.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.learningEngine, required this.repository, super.key});

  final LearningEngine learningEngine;
  final AppLearningRepository repository;

  @override
  Widget build(BuildContext context) => StreamBuilder<DashboardSnapshot>(
        stream: repository.watchDashboard(),
        initialData: repository.dashboard,
        builder: (context, snapshot) {
          final data = snapshot.data ?? repository.dashboard;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Your progress', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _MasteryCard('Recognition', Skill.recognition, repository),
                _MasteryCard('Listening', Skill.listening, repository),
                _MasteryCard('Pinyin conversion', Skill.pinyinConversion, repository),
                _MasteryCard('Keyboard', Skill.keyboard, repository),
                _MasteryCard('Hanzi input', Skill.composition, repository),
              ]),
              const SizedBox(height: 20),
              Card(child: ListTile(title: Text('Due reviews: ${data.dueCount}'), subtitle: Text('Mastered items: ${data.masteredCount}'))),
              const Card(child: ListTile(title: Text('Confusion targets: 0'), subtitle: Text('Practice the distinctions that need attention.'))),
            ],
          );
        },
      );
}

class _MasteryCard extends StatelessWidget {
  const _MasteryCard(this.label, this.skill, this.repository);

  final String label;
  final Skill skill;
  final AppLearningRepository repository;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), const SizedBox(height: 8), Text('${(repository.masteryFor(skill) * 100).round()}%', style: Theme.of(context).textTheme.titleLarge)]))),
      );
}

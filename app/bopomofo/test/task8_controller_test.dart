import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:domain/domain.dart';

import 'package:bopomofo/features/keyboard/keyboard_controller.dart';

import 'test_support.dart';

void main() {
  test('keyboard controller records correct and wrong physical keys', () async {
    final dependencies = await createTestDependencies();
    final controller = KeyboardController(
      repository: dependencies.repository,
      now: () => DateTime.utc(2026, 9, 23),
    );
    controller.setTarget('ㄅ');

    expect(await controller.handleKey('q'), isFalse);
    expect(await controller.handleKey('1'), isTrue);
    expect(controller.metrics.attempts, 2);
    expect(controller.metrics.correct, 1);
    expect(controller.metrics.accuracy, 0.5);
    expect((await dependencies.repository.snapshot()).reviewStates.single.skill, Skill.keyboard);
    expect((await dependencies.repository.local.events.all()).first.response, 'q');
    await dependencies.repository.close();
  });

  test('physical key event records the entered response and updates metrics', () async {
    final dependencies = await createTestDependencies();
    var now = DateTime.utc(2026, 9, 23, 0, 1);
    final controller = KeyboardController(
      repository: dependencies.repository,
      now: () => now,
    )..setTarget('ㄅ');

    now = now.add(const Duration(minutes: 1));
    expect(
      await controller.handlePhysicalKey(const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyQ,
        logicalKey: LogicalKeyboardKey.keyQ,
        character: 'q',
        timeStamp: Duration.zero,
      )),
      isFalse,
    );
    await controller.handleKey('1');
    expect(controller.metrics.attempts, 2);
    expect(controller.metrics.correct, 1);
    expect(controller.metrics.cpm, 1);
    expect((await dependencies.repository.local.events.all()).first.response, 'q');
    await dependencies.repository.close();
  });

  test('keyboard labels can be hidden and listening stays local-only', () async {
    final dependencies = await createTestDependencies();
    final controller = KeyboardController(repository: dependencies.repository);

    controller.toggleLabels();
    expect(controller.labelsVisible, isFalse);
    final prompt = controller.listeningPrompt(localAssetPath: 'assets/audio/ba.mp3');
    expect(prompt.hasLocalAsset, isTrue);
    expect(prompt.assetPath, isNot(contains('http')));
    expect(controller.listeningPrompt().hasLocalAsset, isFalse);
    await dependencies.repository.close();
  });
}

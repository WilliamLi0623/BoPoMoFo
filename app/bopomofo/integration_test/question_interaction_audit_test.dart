import 'package:integration_test/integration_test.dart';

import '../test/review/question_view_test.dart' as questions;

// Exercise the same five-type interaction regressions using the real Android
// view and input connection. The question fixtures use silent fake audio.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  questions.main();
}

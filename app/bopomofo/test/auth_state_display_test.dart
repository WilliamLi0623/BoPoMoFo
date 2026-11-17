import 'dart:async';

import 'package:auth/auth.dart';
import 'package:bopomofo/bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

class _ControllableAuth implements AuthService {
  final _changes = StreamController<AuthState>.broadcast();
  User? user;

  void signIn(User value) {
    user = value;
    _changes.add(AuthState.authenticated(value));
  }

  @override
  Stream<AuthState> get authStateChanges => _changes.stream;

  @override
  User? get currentUser => user;

  @override
  Future<User?> signInWithGoogle() async => null;

  @override
  Future<User?> signInWithApple() async => null;

  @override
  Future<void> signOut() async => user = null;

  @override
  Future<void> deleteAccount() async {}
}

User _user({required String email, Map<String, Object?> appMetadata = const {}}) =>
    User.fromJson({
      'id': '11111111-1111-4111-8111-111111111111',
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': email,
      'app_metadata': appMetadata,
      'user_metadata': <String, Object?>{},
      'created_at': DateTime.utc(2026).toIso8601String(),
    })!;

void main() {
  test('signedInUser ignores the local guest identity', () async {
    final guest = await GuestAuthService.create(store: InMemoryGuestIdStore());
    expect(guest.currentUser, isNotNull);
    expect(guest.signedInUser, isNull);

    final auth = _ControllableAuth()..user = _user(email: 'a@example.test');
    expect(auth.signedInUser?.email, 'a@example.test');
  });

  testWidgets('onboarding switches from guest to signed in when the session arrives',
      (tester) async {
    final base = await createTestDependencies();
    final auth = _ControllableAuth();
    final dependencies = AppDependencies(
      configuration: base.configuration,
      authService: auth,
      syncService: base.syncService,
      learningEngine: base.learningEngine,
      repository: base.repository,
    );

    await tester.pumpWidget(BopomofoApp(
      dependencies: dependencies,
      localeController: await createEnglishLocaleController(),
    ));
    expect(find.text('Guest mode · saved locally'), findsOneWidget);

    auth.signIn(_user(email: 'a@example.test'));
    await tester.pump();

    expect(find.text('Signed in · a@example.test'), findsOneWidget);
    expect(find.text('Guest mode · saved locally'), findsNothing);
  });
}

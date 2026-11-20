import 'dart:convert';

import 'package:auth/auth.dart';
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:test/test.dart';

void main() {
  final user = User(
    id: 'signed-in-user',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-11-19T00:00:00Z',
  );

  test(
    'native ID token and matching raw nonce reach session exchange',
    () async {
      final google = FakeGoogleSignIn();
      String? exchangedNonce;
      final signIn = NativeGoogleSignIn(
        serverClientId: 'web-client-id',
        googleSignIn: google,
        exchangeIdToken: ({required idToken, required nonce}) async {
          expect(idToken, 'google-id-token');
          exchangedNonce = nonce;
          return user;
        },
      );
      expect(await signIn.signIn(), same(user));
      expect(google.serverClientId, 'web-client-id');
      expect(
        google.nonce,
        sha256.convert(utf8.encode(exchangedNonce!)).toString(),
      );
      expect(exchangedNonce!.length, greaterThanOrEqualTo(32));
      await signIn.signIn();
      expect(google.initializeCalls, 1);
    },
  );

  test('missing Web client ID fails before calling Google', () async {
    final google = FakeGoogleSignIn();
    final signIn = NativeGoogleSignIn(
      serverClientId: ' ',
      googleSignIn: google,
      exchangeIdToken: ({required idToken, required nonce}) async => user,
    );
    await expectLater(signIn.signIn(), throwsA(isA<AuthConfigurationError>()));
    expect(google.initializeCalls, 0);
  });

  test('cancellation is typed and never exchanges a token', () async {
    final google = FakeGoogleSignIn()
      ..error = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
    final signIn = NativeGoogleSignIn(
      serverClientId: 'web-client-id',
      googleSignIn: google,
      exchangeIdToken: ({required idToken, required nonce}) async {
        fail('Cancelled sign-in must not reach Supabase');
      },
    );
    await expectLater(
      signIn.signIn(),
      throwsA(
        isA<AuthFailure>().having(
          (e) => e.kind,
          'kind',
          AuthFailureKind.cancelled,
        ),
      ),
    );
  });

  test('missing Google ID token is a failure, not a launched login', () async {
    final signIn = NativeGoogleSignIn(
      serverClientId: 'web-client-id',
      googleSignIn: FakeGoogleSignIn()..token = null,
      exchangeIdToken: ({required idToken, required nonce}) async {
        fail('Missing token must not reach Supabase');
      },
    );
    await expectLater(signIn.signIn(), throwsA(isA<AuthFailure>()));
  });

  test('an exchange without a user is not reported as successful', () async {
    final signIn = NativeGoogleSignIn(
      serverClientId: 'web-client-id',
      googleSignIn: FakeGoogleSignIn(),
      exchangeIdToken: ({required idToken, required nonce}) async => null,
    );
    await expectLater(signIn.signIn(), throwsA(isA<AuthFailure>()));
  });

  test('provider exchange errors propagate to the auth service', () async {
    final error = StateError('exchange rejected');
    final signIn = NativeGoogleSignIn(
      serverClientId: 'web-client-id',
      googleSignIn: FakeGoogleSignIn(),
      exchangeIdToken: ({required idToken, required nonce}) async =>
          throw error,
    );
    await expectLater(signIn.signIn(), throwsA(same(error)));
  });
}

class FakeGoogleSignIn implements GoogleSignIn {
  int initializeCalls = 0;
  String? serverClientId;
  String? nonce;
  String? token = 'google-id-token';
  GoogleSignInException? error;

  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? nonce,
    String? hostedDomain,
  }) async {
    initializeCalls++;
    this.serverClientId = serverClientId;
    this.nonce = nonce;
  }

  @override
  Future<GoogleSignInAccount> authenticate({
    List<String> scopeHint = const [],
  }) async {
    if (error != null) throw error!;
    return FakeGoogleAccount(token);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeGoogleAccount implements GoogleSignInAccount {
  FakeGoogleAccount(this.token);
  final String? token;
  @override
  GoogleSignInAuthentication get authentication =>
      GoogleSignInAuthentication(idToken: token);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

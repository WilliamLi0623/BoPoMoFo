import 'dart:io';

import 'package:auth/auth.dart' as app_auth;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:auth/auth.dart'
    show
        AuthConfiguration,
        AuthConfigurationError,
        AuthFailure,
        AuthFailureKind,
        SupabaseAuthService,
        AuthGateway;
import 'package:test/test.dart';

void main() {
  test('missing environment configuration fails with a typed error', () {
    expect(
      () => AuthConfiguration.fromEnvironment(const {}),
      throwsA(
        isA<AuthConfigurationError>().having(
          (error) => error.missing,
          'missing',
          [
            'SUPABASE_URL',
            'SUPABASE_PUBLISHABLE_KEY',
            'GOOGLE_OAUTH_REDIRECT_URI'
          ],
        ),
      ),
    );
  });

  test('whitespace-only configuration fails closed with exact missing names',
      () {
    expect(
      () => AuthConfiguration.fromEnvironment(const {
        'SUPABASE_URL': '  ',
        'SUPABASE_PUBLISHABLE_KEY': '\t',
        'GOOGLE_OAUTH_REDIRECT_URI': '\n',
      }),
      throwsA(
        isA<AuthConfigurationError>().having(
          (error) => error.missing,
          'missing',
          [
            'SUPABASE_URL',
            'SUPABASE_PUBLISHABLE_KEY',
            'GOOGLE_OAUTH_REDIRECT_URI'
          ],
        ),
      ),
    );
  });

  test('provider exceptions are mapped to typed provider failures', () async {
    final gateway = FakeAuthGateway(
      oauthSignIn: (_, __) async {
        throw AuthException('provider rejected the request');
      },
    );
    final service = SupabaseAuthService(
      configuration: _configuration(),
      gateway: gateway,
    );

    expect(
      () => service.signInWithGoogle(),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.kind,
          'kind',
          AuthFailureKind.provider,
        ),
      ),
    );
  });

  test('a cancelled OAuth launch is mapped to a cancellation failure',
      () async {
    final service = SupabaseAuthService(
      configuration: _configuration(),
      gateway: FakeAuthGateway(oauthSignIn: (_, __) async => false),
    );

    expect(
      () => service.signInWithGoogle(),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.kind,
          'kind',
          AuthFailureKind.cancelled,
        ),
      ),
    );
  });

  test('provider and redirect values reach the gateway unchanged', () async {
    final gateway = FakeAuthGateway(oauthSignIn: (_, __) async => true);
    final service = SupabaseAuthService(
      configuration: _configuration(),
      gateway: gateway,
    );

    await service.signInWithGoogle();

    expect(gateway.lastProvider, OAuthProvider.google);
    expect(gateway.lastRedirect, 'com.bopomofo://auth/callback');
  });

  test('account deletion delegates to the authenticated gateway', () async {
    final gateway = FakeAuthGateway();
    final service = SupabaseAuthService(
      configuration: _configuration(),
      gateway: gateway,
    );

    await service.deleteAccount();

    expect(gateway.deleteAccountCalls, 1);
  });

  test('a null gateway user maps to unauthenticated auth state', () async {
    final service = SupabaseAuthService(
      configuration: _configuration(),
      gateway: FakeAuthGateway(),
    );

    expect(await service.authStateChanges.first,
        const app_auth.AuthState.unauthenticated());
    expect(service.currentUser, isNull);
  });

  test('Apple sign-in is gated to iOS and macOS', () async {
    final service = SupabaseAuthService(
      configuration: _configuration(),
      gateway: FakeAuthGateway(),
    );

    if (Platform.isIOS || Platform.isMacOS) {
      expect(service.isAppleAvailable, isTrue);
    } else {
      expect(service.isAppleAvailable, isFalse);
      expect(
        () => service.signInWithApple(),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.kind,
            'kind',
            AuthFailureKind.unsupportedPlatform,
          ),
        ),
      );
    }
  });
}

AuthConfiguration _configuration() => const AuthConfiguration(
      supabaseUrl: 'https://example.supabase.co',
      publishableKey: 'publishable-key',
      googleRedirectUri: 'com.bopomofo://auth/callback',
      appleRedirectUri: 'com.bopomofo://auth/apple-callback',
    );

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.oauthSignIn});

  final Future<bool> Function(OAuthProvider provider, String redirectTo)?
      oauthSignIn;

  OAuthProvider? lastProvider;
  String? lastRedirect;
  int deleteAccountCalls = 0;

  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStateChanges => Stream<User?>.value(null);

  @override
  Future<bool> signInWithOAuth(OAuthProvider provider, String redirectTo) {
    lastProvider = provider;
    lastRedirect = redirectTo;
    return oauthSignIn?.call(provider, redirectTo) ?? Future.value(false);
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalls++;
  }
}

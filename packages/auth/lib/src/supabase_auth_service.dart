import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'auth_configuration.dart';
import 'auth_service.dart';
import 'auth_state.dart';

abstract interface class AuthGateway {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  Future<bool> signInWithOAuth(OAuthProvider provider, String redirectTo);
  Future<void> signOut();
  Future<void> deleteAccount();
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this.client);

  final SupabaseClient client;

  static Future<SupabaseAuthGateway> initialize(
    AuthConfiguration configuration,
  ) async {
    configuration.validate();
    await Supabase.initialize(
      url: configuration.supabaseUrl,
      publishableKey: configuration.publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    return SupabaseAuthGateway(Supabase.instance.client);
  }

  @override
  Stream<User?> get authStateChanges =>
      client.auth.onAuthStateChange.map((change) => change.session?.user);

  @override
  User? get currentUser => client.auth.currentUser;

  @override
  Future<bool> signInWithOAuth(OAuthProvider provider, String redirectTo) =>
      client.auth.signInWithOAuth(provider, redirectTo: redirectTo);

  @override
  Future<void> signOut() => client.auth.signOut();

  @override
  Future<void> deleteAccount() async {
    await client.rpc('delete_own_account');
  }
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(
      {required AuthConfiguration configuration, required AuthGateway gateway})
      : _configuration = configuration,
        _gateway = gateway {
    _configuration.validate();
  }

  final AuthConfiguration _configuration;
  final AuthGateway _gateway;

  bool get isAppleAvailable => Platform.isIOS || Platform.isMacOS;

  @override
  Stream<AuthState> get authStateChanges => _gateway.authStateChanges.map(
        (user) => user == null
            ? const AuthState.unauthenticated()
            : AuthState.authenticated(user),
      );

  @override
  User? get currentUser => _gateway.currentUser;

  @override
  Future<User?> signInWithGoogle() =>
      _signIn(OAuthProvider.google, _configuration.googleRedirectUri);

  @override
  Future<User?> signInWithApple() {
    if (!isAppleAvailable) {
      throw const AuthFailure(
        kind: AuthFailureKind.unsupportedPlatform,
        message: 'Apple sign-in is available only on iOS and macOS.',
      );
    }
    final redirectTo = _configuration.appleRedirectUri;
    if (redirectTo == null || redirectTo.isEmpty) {
      throw AuthConfigurationError(const ['APPLE_REDIRECT_URI']);
    }
    return _signIn(OAuthProvider.apple, redirectTo);
  }

  Future<User?> _signIn(OAuthProvider provider, String redirectTo) async {
    try {
      final launched = await _gateway.signInWithOAuth(provider, redirectTo);
      if (!launched) {
        throw const AuthFailure(
          kind: AuthFailureKind.cancelled,
          message: 'The OAuth sign-in was cancelled.',
        );
      }
      return currentUser;
    } on AuthFailure {
      rethrow;
    } on AuthException catch (error) {
      throw AuthFailure(
        kind: AuthFailureKind.provider,
        message: error.message,
        cause: error,
      );
    } catch (error) {
      throw AuthFailure(
        kind: AuthFailureKind.provider,
        message: 'OAuth sign-in failed.',
        cause: error,
      );
    }
  }

  @override
  Future<void> signOut() => _mapProviderErrors(_gateway.signOut());

  @override
  Future<void> deleteAccount() => _mapProviderErrors(_gateway.deleteAccount());

  Future<void> _mapProviderErrors(Future<void> operation) async {
    try {
      await operation;
    } on AuthFailure {
      rethrow;
    } on AuthException catch (error) {
      throw AuthFailure(
        kind: AuthFailureKind.provider,
        message: error.message,
        cause: error,
      );
    } catch (error) {
      throw AuthFailure(
        kind: AuthFailureKind.provider,
        message: 'Authentication operation failed.',
        cause: error,
      );
    }
  }
}

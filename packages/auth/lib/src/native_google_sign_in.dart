import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'auth_configuration.dart';

/// Android account selection followed by a Supabase session exchange.
/// Keep one instance for the application's auth service: the Google SDK must
/// initialize only once, and its nonce is fixed for that SDK instance.
class NativeGoogleSignIn {
  NativeGoogleSignIn({
    required this.serverClientId,
    required this.exchangeIdToken,
    GoogleSignIn? googleSignIn,
  }) : _google = googleSignIn ?? GoogleSignIn.instance;

  final String serverClientId;
  final Future<User?> Function({required String idToken, required String nonce})
  exchangeIdToken;
  final GoogleSignIn _google;
  final String _nonce = _newNonce();
  Future<void>? _initialization;

  static String _newNonce() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  Future<User> signIn() async {
    if (serverClientId.trim().isEmpty) {
      throw AuthConfigurationError(const ['GOOGLE_OAUTH_CLIENT_ID']);
    }
    try {
      await (_initialization ??= _google.initialize(
        serverClientId: serverClientId.trim(),
        nonce: sha256.convert(utf8.encode(_nonce)).toString(),
      ));
      final account = await _google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthFailure(
          kind: AuthFailureKind.provider,
          message: 'Google did not return an ID token.',
        );
      }
      final user = await exchangeIdToken(idToken: idToken, nonce: _nonce);
      if (user == null) {
        throw const AuthFailure(
          kind: AuthFailureKind.provider,
          message: 'Google sign-in did not establish a Supabase session.',
        );
      }
      return user;
    } on GoogleSignInException catch (error) {
      throw AuthFailure(
        kind: error.code == GoogleSignInExceptionCode.canceled
            ? AuthFailureKind.cancelled
            : AuthFailureKind.provider,
        message: 'Google sign-in failed (${error.code.name}).',
        cause: error,
      );
    }
  }
}

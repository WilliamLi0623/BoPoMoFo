import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'auth_state.dart';

export 'package:supabase_flutter/supabase_flutter.dart' show User;

abstract interface class AuthService {
  Stream<AuthState> get authStateChanges;
  Future<User?> signInWithGoogle();
  Future<User?> signInWithApple();
  Future<void> signOut();
  Future<void> deleteAccount();
  User? get currentUser;
}

extension SignedInUser on AuthService {
  /// The current user when it is a real account session, or null in guest
  /// mode (the local guest identity is also a [User], marked `is_guest`).
  User? get signedInUser {
    final user = currentUser;
    if (user == null || user.appMetadata['is_guest'] == true) return null;
    return user;
  }
}

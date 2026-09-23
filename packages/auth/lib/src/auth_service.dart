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

import 'package:supabase_flutter/supabase_flutter.dart' show User;

enum AuthStatus { unauthenticated, authenticated }

class AuthState {
  const AuthState._({required this.status, this.user, this.failure});

  const AuthState.unauthenticated([User? user])
      : this._(status: AuthStatus.unauthenticated, user: user);

  const AuthState.authenticated(User user)
      : this._(status: AuthStatus.authenticated, user: user);

  final AuthStatus status;
  final User? user;
  final Object? failure;

  @override
  bool operator ==(Object other) =>
      other is AuthState &&
      other.status == status &&
      other.user?.id == user?.id;

  @override
  int get hashCode => Object.hash(status, user?.id);
}

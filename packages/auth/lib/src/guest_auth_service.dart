import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:domain/domain.dart';

import 'auth_configuration.dart';
import 'auth_service.dart';
import 'auth_state.dart';

abstract interface class GuestIdStore {
  Future<UserId?> read();
  Future<void> write(UserId id);
}

class InMemoryGuestIdStore implements GuestIdStore {
  UserId? _id;

  @override
  Future<UserId?> read() async => _id;

  @override
  Future<void> write(UserId id) async => _id = id;
}

class SharedPreferencesGuestIdStore implements GuestIdStore {
  const SharedPreferencesGuestIdStore(this.preferences);

  static const key = 'bopomofo.guest_user_id';

  final SharedPreferences preferences;

  @override
  Future<UserId?> read() async => preferences.getString(key);

  @override
  Future<void> write(UserId id) async {
    if (!await preferences.setString(key, id)) {
      throw StateError('Could not persist the local guest identity.');
    }
  }
}

class GuestAuthService implements AuthService {
  GuestAuthService._({required User guest}) : _guest = guest;

  static Future<GuestAuthService> create({required GuestIdStore store}) async {
    final existingId = await store.read();
    final id = existingId ?? const Uuid().v4();
    if (existingId == null) await store.write(id);
    return GuestAuthService._(guest: _guestUser(id));
  }

  static Future<GuestAuthService> createPersistent() async {
    final preferences = await SharedPreferences.getInstance();
    return create(store: SharedPreferencesGuestIdStore(preferences));
  }

  final User _guest;

  User get guestUser => _guest;
  AuthState get authState => AuthState.unauthenticated(_guest);

  @override
  Stream<AuthState> get authStateChanges => Stream<AuthState>.value(authState);

  @override
  User? get currentUser => _guest;

  @override
  Future<User?> signInWithGoogle() =>
      Future<User?>.error(const AuthFailure(
        kind: AuthFailureKind.provider,
        message: 'Guest mode does not create a cloud session.',
      ));

  @override
  Future<User?> signInWithApple() =>
      Future<User?>.error(const AuthFailure(
        kind: AuthFailureKind.provider,
        message: 'Guest mode does not create a cloud session.',
      ));

  @override
  Future<void> signOut() async {
    // Signing out never removes local progress or the stable guest identity.
  }

  @override
  Future<void> deleteAccount() async {
    // A guest has no cloud account to delete. Local data deletion is separate.
  }

  static User _guestUser(String id) {
    final now = DateTime.now().toUtc().toIso8601String();
    return User.fromJson({
      'id': id,
      'aud': 'guest',
      'role': 'guest',
      'email': null,
      'phone': '',
      'app_metadata': {'is_guest': true},
      'user_metadata': <String, Object?>{},
      'identities': <Object?>[],
      'created_at': now,
      'updated_at': now,
    })!;
  }
}

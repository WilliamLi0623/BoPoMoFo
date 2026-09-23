import 'package:auth/auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

void main() {
  test('guest identity survives a service restart through the same local store', () async {
    final store = InMemoryGuestIdStore();
    final first = await GuestAuthService.create(store: store);
    final second = await GuestAuthService.create(store: store);

    expect(first.currentUser, isNotNull);
    expect(first.currentUser!.id, second.currentUser!.id);
    expect(first.currentUser!.appMetadata['is_guest'], isTrue);
    expect(first.authState, AuthState.unauthenticated(first.currentUser));
  });

  test('shared preferences store preserves the guest identity across restart', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesGuestIdStore(preferences);

    final first = await GuestAuthService.create(store: store);
    final second = await GuestAuthService.create(
      store: SharedPreferencesGuestIdStore(preferences),
    );

    expect(second.currentUser!.id, first.currentUser!.id);
  });

  test('sign out keeps the local guest identity and remains unauthenticated', () async {
    final store = InMemoryGuestIdStore();
    final service = await GuestAuthService.create(store: store);
    final guestId = service.currentUser!.id;

    await service.signOut();

    expect(service.currentUser!.id, guestId);
    expect(service.authState.status, AuthStatus.unauthenticated);
    expect(service.currentUser!.appMetadata['is_guest'], isTrue);
  });
}

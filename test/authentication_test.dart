import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:syskata/core/authentication.dart';

class MemoryVault implements AuthVault {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class FakeIdentity implements IdentityService {
  String user = 'learner-a';
  bool failRefresh = false;
  int refreshes = 0;
  Completer<LoginTokens>? refreshPending;
  LoginTokens tokens = LoginTokens(
    'access-placeholder',
    'refresh-placeholder',
    DateTime.now().add(const Duration(minutes: 5)),
  );
  @override
  Future<LoginTokens> signIn(Installation installation) async => tokens;
  @override
  Future<String> subject(Installation installation, String accessToken) async =>
      user;
  @override
  Future<LoginTokens> refresh(
    Installation installation,
    String refreshToken,
  ) async {
    refreshes++;
    if (failRefresh) throw StateError('expired');
    return refreshPending?.future ?? tokens;
  }

  @override
  Future<void> revoke(Installation installation, String refreshToken) async {}
}

void main() {
  test(
    'installation requires HTTPS and exact realm, canonicalizes API origin',
    () {
      expect(
        Installation(
          'https://api.example/',
          'https://id.example/realms/syskata',
        ).api.toString(),
        'https://api.example',
      );
      for (final api in [
        'http://api.example',
        'https://u:p@api.example',
        'https://api.example/path',
        'https://api.example?token=x',
      ]) {
        expect(
          () => Installation(api, 'https://id.example/realms/syskata'),
          throwsFormatException,
        );
      }
      expect(
        () => Installation('https://api.example', 'https://id.example'),
        throwsFormatException,
      );
    },
  );
  test('restart restores installation and credentials; accounts bind to issuer and API', () async {
    final vault = MemoryVault(), identity = FakeIdentity();
    final auth = Authentication(vault, identity, (_) async {});
    await auth.initialize();
    await auth.configure(
      Installation('https://api.example', 'https://id.example/realms/syskata'),
    );
    await auth.signIn();
    final restarted = Authentication(vault, identity, (_) async {});
    await restarted.initialize();
    expect(restarted.signedIn, isTrue);
    expect(restarted.accountId, auth.accountId);
    expect(await restarted.accessToken(), 'access-placeholder');
    expect(
      Installation(
        'https://other-api.example',
        'https://id.example/realms/syskata',
      ).account('learner-a'),
      isNot(auth.accountId),
    );
  });
  test('refresh failure retains pending account identity; switching account clears it', () async {
    final vault = MemoryVault(), identity = FakeIdentity();
    final cleared = <String>[];
    final auth = Authentication(vault, identity, (account) async {
      cleared.add(account);
    });
    await auth.configure(
      Installation('https://api.example', 'https://id.example/realms/syskata'),
    );
    identity.tokens = LoginTokens(
      'access-placeholder',
      'refresh-placeholder',
      DateTime.now().subtract(const Duration(seconds: 1)),
    );
    await auth.signIn();
    final old = auth.accountId;
    identity.failRefresh = true;
    expect(await auth.accessToken(), isNull);
    expect(auth.signedIn, isFalse);
    expect(cleared, isEmpty);
    identity.user = 'learner-b';
    await auth.signIn();
    expect(cleared, [old]);
  });
  test(
    'concurrent refresh is single-flight and late response cannot undo logout',
    () async {
      final vault = MemoryVault(), identity = FakeIdentity();
      final cleared = <String>[];
      final auth = Authentication(vault, identity, (account) async {
        cleared.add(account);
      });
      await auth.configure(
        Installation(
          'https://api.example',
          'https://id.example/realms/syskata',
        ),
      );
      identity.tokens = LoginTokens(
        'old-placeholder',
        'refresh-placeholder',
        DateTime.now().subtract(const Duration(seconds: 1)),
      );
      await auth.signIn();
      identity.refreshPending = Completer<LoginTokens>();
      final first = auth.accessToken(), second = auth.accessToken();
      final logout = auth.signOut();
      identity.refreshPending!.complete(
        LoginTokens(
          'new-placeholder',
          'rotated-placeholder',
          DateTime.now().add(const Duration(minutes: 5)),
        ),
      );
      await logout;
      expect(await first, isNull);
      expect(await second, isNull);
      expect(identity.refreshes, 1);
      expect(auth.signedIn, isFalse);
      expect(vault.values.containsKey('auth'), isFalse);
      expect(cleared, hasLength(1));
    },
  );
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

const mobileCallback = 'org.syskata.app:/oauth2redirect';
const mobileClient = 'syskata-mobile';

class Installation {
  Installation(String api, String identity)
    : api = _https(api, origin: true),
      issuer = _https(identity, origin: false);
  final Uri api, issuer;
  static Uri _https(String value, {required bool origin}) {
    final uri = Uri.parse(value.trim());
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (origin && uri.path.isNotEmpty && uri.path != '/') ||
        (!origin && !RegExp(r'^/realms/[a-zA-Z0-9._-]+$').hasMatch(uri.path))) {
      throw const FormatException(
        'Enter an HTTPS API origin and Keycloak realm URL.',
      );
    }
    return uri.replace(path: origin ? '' : uri.path);
  }

  Map<String, dynamic> toJson() => {
    'api': api.toString(),
    'issuer': issuer.toString(),
  };
  factory Installation.fromJson(Json value) =>
      Installation(value['api'] as String, value['issuer'] as String);
  String account(String subject) =>
      jsonEncode([api.toString(), issuer.toString(), subject]);
}

abstract interface class AuthVault {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureAuthVault implements AuthVault {
  const SecureAuthVault();
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  @override
  Future<String?> read(String key) => _storage.read(key: 'syskata.$key');
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: 'syskata.$key', value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: 'syskata.$key');
}

class LoginTokens {
  const LoginTokens(this.access, this.refresh, this.expires);
  final String access, refresh;
  final DateTime expires;
  factory LoginTokens.fromResponse(
    TokenResponse response, {
    String? previousRefresh,
  }) {
    final access = response.accessToken;
    final refresh = response.refreshToken ?? previousRefresh;
    final expires = response.accessTokenExpirationDateTime;
    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty ||
        expires == null) {
      throw const ServiceFailure(
        code: 'invalid_identity_response',
        retryable: false,
        recovery: 'sign_in',
      );
    }
    return LoginTokens(access, refresh, expires);
  }
  Json toJson() => {
    'access': access,
    'refresh': refresh,
    'expires': expires.toUtc().toIso8601String(),
  };
  factory LoginTokens.fromJson(Json json) => LoginTokens(
    json['access'] as String,
    json['refresh'] as String,
    DateTime.parse(json['expires'] as String),
  );
}

abstract interface class IdentityService {
  Future<LoginTokens> signIn(Installation installation);
  Future<LoginTokens> refresh(Installation installation, String refreshToken);
  Future<String> subject(Installation installation, String accessToken);
  Future<void> revoke(Installation installation, String refreshToken);
}

class KeycloakIdentity implements IdentityService {
  KeycloakIdentity(this.client, {this.appAuth = const FlutterAppAuth()});
  final http.Client client;
  final FlutterAppAuth appAuth;
  @override
  Future<LoginTokens> signIn(Installation installation) async =>
      LoginTokens.fromResponse(
        await appAuth.authorizeAndExchangeCode(
          AuthorizationTokenRequest(
            mobileClient,
            mobileCallback,
            issuer: installation.issuer.toString(),
            scopes: ['openid', 'profile'],
            promptValues: ['login'],
          ),
        ),
      );
  @override
  Future<LoginTokens> refresh(
    Installation installation,
    String refreshToken,
  ) async => LoginTokens.fromResponse(
    await appAuth.token(
      TokenRequest(
        mobileClient,
        mobileCallback,
        issuer: installation.issuer.toString(),
        refreshToken: refreshToken,
      ),
    ),
    previousRefresh: refreshToken,
  );
  @override
  Future<String> subject(Installation installation, String accessToken) async {
    final response = await _send(installation, 'userinfo', token: accessToken);
    final subject = object(jsonDecode(response.body))['sub'];
    if (subject is! String || subject.isEmpty) {
      throw const FormatException('Invalid identity response');
    }
    return subject;
  }

  @override
  Future<void> revoke(Installation installation, String refreshToken) async {
    await _send(
      installation,
      'revoke',
      body: {
        'client_id': mobileClient,
        'token': refreshToken,
        'token_type_hint': 'refresh_token',
      },
    );
  }

  Future<http.Response> _send(
    Installation installation,
    String endpoint, {
    String? token,
    Map<String, String>? body,
  }) async {
    final request = http.Request(
      body == null ? 'GET' : 'POST',
      Uri.parse('${installation.issuer}/protocol/openid-connect/$endpoint'),
    );
    request.followRedirects = false;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.bodyFields = body;
    final response = await http.Response.fromStream(await client.send(request))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw const ServiceFailure(
        code: 'identity_unavailable',
        retryable: false,
        recovery: 'sign_in',
      );
    }
    return response;
  }
}

/// Generation checks prevent late refresh/login results from restoring a signed-out account.
class Authentication extends ChangeNotifier {
  Authentication(this.vault, this.identity, this.clearAccount);
  final AuthVault vault;
  final IdentityService identity;
  final Future<void> Function(String account) clearAccount;
  Installation? installation;
  LoginTokens? _tokens;
  String? accountId;
  String? message;
  bool loading = true, busy = false;
  int _generation = 0;
  Future<String?>? _refreshing;
  int get generation => _generation;
  bool get signedIn => _tokens != null && accountId != null;
  Future<void> initialize() async {
    try {
      final settings = await vault.read('installation');
      if (settings != null) {
        installation = Installation.fromJson(object(jsonDecode(settings)));
      }
      final saved = await vault.read('auth');
      if (saved != null && installation != null) {
        final data = object(jsonDecode(saved));
        if (data['issuer'] == installation!.issuer.toString() &&
            data['api'] == installation!.api.toString()) {
          accountId = data['account'] as String;
          _tokens = LoginTokens.fromJson(object(data['tokens']));
          await accessToken();
        } else {
          await vault.delete('auth');
        }
      }
    } catch (_) {
      _tokens = null;
      message = 'Could not restore sign-in. Sign in again.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> configure(Installation value) async {
    if (busy || signedIn) return;
    await vault.write('installation', jsonEncode(value.toJson()));
    installation = value;
    message = null;
    notifyListeners();
  }

  Future<void> signIn() async {
    if (busy || installation == null) return;
    busy = true;
    message = null;
    final generation = ++_generation;
    final config = installation!;
    notifyListeners();
    try {
      final tokens = await identity.signIn(config);
      final subject = await identity.subject(config, tokens.access);
      if (generation != _generation) return;
      final account = config.account(subject);
      final previous = await vault.read('last_account');
      if (previous != null && previous != account) await clearAccount(previous);
      await vault.write('last_account', account);
      accountId = account;
      await _save(tokens);
      _tokens = tokens;
    } on FlutterAppAuthUserCancelledException {
      message = 'Sign-in cancelled.';
    } catch (_) {
      _tokens = null;
      message = 'Could not sign in. Check the server settings and try again.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _save(LoginTokens tokens) => vault.write(
    'auth',
    jsonEncode({
      ...installation!.toJson(),
      'account': accountId,
      'tokens': tokens.toJson(),
    }),
  );
  Future<String?> accessToken() async {
    if (!signedIn) return null;
    if (_tokens!.expires.isAfter(
      DateTime.now().add(const Duration(seconds: 30)),
    )) {
      return _tokens!.access;
    }
    final pending = _refreshing;
    if (pending != null) return pending;
    final future = _refresh();
    _refreshing = future;
    try {
      return await future;
    } finally {
      _refreshing = null;
    }
  }

  Future<String?> _refresh() async {
    final generation = _generation;
    try {
      final tokens = await identity.refresh(installation!, _tokens!.refresh);
      if (generation != _generation) return null;
      await _save(tokens);
      if (generation != _generation) return null;
      _tokens = tokens;
      return tokens.access;
    } catch (_) {
      if (generation == _generation) await expire();
      return null;
    }
  }

  Future<void> expire({bool deleted = false}) async {
    ++_generation;
    _tokens = null;
    await vault.delete('auth');
    if (deleted && accountId != null) await clearAccount(accountId!);
    message = deleted
        ? 'This account is unavailable. Local learning data was cleared.'
        : 'Your sign-in expired. Sign in again to recover pending work.';
    notifyListeners();
  }

  Future<void> signOut() async {
    if (busy) return;
    busy = true;
    ++_generation;
    final tokens = _tokens;
    final config = installation;
    final account = accountId;
    _tokens = null;
    notifyListeners();
    try {
      await _refreshing;
      await vault.delete('auth');
      if (account != null) await clearAccount(account);
      await vault.delete('last_account');
      accountId = null;
      if (tokens != null && config != null) {
        try {
          await identity.revoke(config, tokens.refresh);
        } catch (_) {
          message = 'Signed out locally. Server token revocation could not be confirmed.';
        }
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

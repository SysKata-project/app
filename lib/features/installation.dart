import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../app/app.dart';
import '../app/providers.dart';
import '../core/authentication.dart';
import '../core/config.dart';
import '../core/services.dart';
import '../core/storage.dart';

final authenticationProvider = Provider<Authentication?>((ref) => null);
final recoveryJournalProvider = Provider<RecoveryJournal?>((ref) => null);

class InstallationApp extends StatefulWidget {
  const InstallationApp({super.key});
  @override
  State<InstallationApp> createState() => _InstallationAppState();
}

class _InstallationAppState extends State<InstallationApp> {
  final client = http.Client();
  Authentication? auth;
  RecoveryStore? store;
  String? error;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      store = await RecoveryStore.open();
      final value = Authentication(
        const SecureAuthVault(),
        KeycloakIdentity(client),
        store!.clearAccount,
      );
      auth = value;
      await value.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not open secure local storage. Restart the app to try again.',
        );
      }
    }
  }

  @override
  void dispose() {
    auth?.dispose();
    client.close();
    store?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = auth;
    if (value == null || value.loading) {
      return MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: error == null
                  ? const CircularProgressIndicator(
                      semanticsLabel: 'Opening secure storage',
                    )
                  : Text(error!),
            ),
          ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: value,
      builder: (context, _) {
        if (!value.signedIn) {
          return MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: SetupScreen(auth: value),
          );
        }
        final installation = value.installation!;
        final generation = value.generation;
        return ProviderScope(
          key: ValueKey(value.accountId),
          overrides: [
            authenticationProvider.overrideWithValue(value),
            recoveryJournalProvider.overrideWithValue(
              ScopedRecoveryJournal(
                store!,
                () => value.signedIn && value.generation == generation,
              ),
            ),
            configProvider.overrideWithValue(
              AppConfig(
                environment: 'configured',
                useFakeServices: false,
                apiBaseUrl: installation.api,
              ),
            ),
            learningServiceProvider.overrideWithValue(
              HttpLearningService(
                client: client,
                origin: installation.api,
                accessToken: () async {
                  if (value.generation != generation) return null;
                  final token = await value.accessToken();
                  return value.generation == generation ? token : null;
                },
                authenticationFailed: (deleted) async {
                  if (value.generation == generation) {
                    await value.expire(deleted: deleted);
                  }
                },
              ),
            ),
          ],
          child: const SysKataApp(),
        );
      },
    );
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({required this.auth, super.key});
  final Authentication auth;
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final api = TextEditingController(), issuer = TextEditingController();
  String? error;
  bool editing = false, saving = false;
  @override
  void initState() {
    super.initState();
    api.text = widget.auth.installation?.api.toString() ?? '';
    issuer.text = widget.auth.installation?.issuer.toString() ?? '';
  }

  @override
  void dispose() {
    api.dispose();
    issuer.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.auth.configure(Installation(api.text, issuer.text));
      if (mounted) setState(() => editing = false);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              error = 'Enter a valid HTTPS API origin and Keycloak realm URL.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    final configure = auth.installation == null || editing;
    return Scaffold(
      appBar: AppBar(title: const Text('Connect SysKata')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  configure
                      ? 'Choose your learning server'
                      : 'Welcome to SysKata',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                if (configure) ...[
                  const Text(
                    'Enter the addresses supplied by your SysKata operator. You can change servers after signing out.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: api,
                    enabled: !saving,
                    autocorrect: false,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'API address',
                      hintText: 'https://api.cluster.example',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: issuer,
                    enabled: !saving,
                    autocorrect: false,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Keycloak realm address',
                      hintText:
                          'https://identity.cluster.example/realms/syskata',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: saving || auth.busy ? null : save,
                    child: const Text('Save server settings'),
                  ),
                ] else ...[
                  Text('Learning server: ${auth.installation!.api.host}'),
                  Text('Sign-in server: ${auth.installation!.issuer.host}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: auth.busy ? null : auth.signIn,
                    child: const Text('Sign in with your browser'),
                  ),
                  TextButton(
                    onPressed: auth.busy
                        ? null
                        : () => setState(() => editing = true),
                    child: const Text('Change server'),
                  ),
                ],
                if (auth.busy || saving)
                  const LinearProgressIndicator(semanticsLabel: 'Connecting'),
                if (error ?? auth.message case final message?)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(message),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../core/models.dart';
import '../core/services.dart';
import '../core/storage.dart';

final configProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => const SecureCredentialStore(),
);
final learningServiceProvider = Provider<LearningService>((ref) {
  final config = ref.watch(configProvider);
  if (config.useFakeServices) return FixtureLearningService();
  final client = http.Client();
  ref.onDispose(client.close);
  return HttpLearningService(
    client: client,
    origin: config.apiBaseUrl,
    accessToken: ref.watch(credentialStoreProvider).readAccessToken,
  );
});
final catalogProvider = FutureProvider<Catalog>(
  (ref) => ref.watch(learningServiceProvider).catalog(),
  retry: (count, error) => null,
);
final progressProvider = FutureProvider<Progress>(
  (ref) => ref.watch(learningServiceProvider).progress(),
  retry: (count, error) => null,
);

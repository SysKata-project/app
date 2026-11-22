import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:syskata/app/app.dart';
import 'package:syskata/core/storage.dart';
import 'package:syskata/app/providers.dart';
import 'package:syskata/core/models.dart';
import 'package:syskata/core/services.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native lesson mistake, remediation and completion', (
    tester,
  ) async {
    final service = NativeLessonService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [learningServiceProvider.overrideWithValue(service)],
        child: const SysKataApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View journey'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open lesson'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start or resume lesson'));
    await tester.tap(find.text('Start or resume lesson'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Routes'));
    await tester.tap(find.text('Routes'));
    await tester.pump();
    await tester.ensureVisible(find.text('Check answer'));
    await tester.tap(find.text('Check answer'));
    await tester.pumpAndSettle();
    expect(find.text('Let’s check what changed'), findsOneWidget);
    await tester.ensureVisible(find.text('Practice the missed objective'));
    await tester.tap(find.text('Practice the missed objective'));
    await tester.pumpAndSettle();
    service.response = 'partial-progress';
    await tester.ensureVisible(find.text('Pods'));
    await tester.tap(find.text('Pods'));
    await tester.pump();
    await tester.ensureVisible(find.text('Check answer'));
    await tester.tap(find.text('Check answer'));
    await tester.pumpAndSettle();
    expect(find.text('Session complete'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('launch, tabs and native recovery persistence', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SysKataApp()));
    await tester.pumpAndSettle();
    expect(find.text('One more rep?'), findsOneWidget);
    for (final tab in ['Learn', 'Review', 'Profile', 'Today']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    var store = await RecoveryStore.open();
    await store.clearAccount('integration-test');
    await store.save(
      const RecoveryRecord(
        accountId: 'integration-test',
        sessionId: 's',
        bundleVersion: '1.0.0',
        instanceId: 'i',
        idempotencyKey: 'same-key',
        payload: '{"sample":true}',
      ),
    );
    await store.close();
    store = await RecoveryStore.open();
    expect(
      (await store.read('integration-test', 's'))!.idempotencyKey,
      'same-key',
    );
    expect(
      (await store.read('integration-test', 's'))!.payload,
      '{"sample":true}',
    );
    expect(await store.read('another-account', 's'), isNull);
    await store.clearAccount('integration-test');
    expect(await store.read('integration-test', 's'), isNull);
    await store.close();
    const credentials = SecureCredentialStore();
    await credentials.writeAccessToken('integration-test-placeholder');
    expect(await credentials.readAccessToken(), 'integration-test-placeholder');
    await credentials.clear();
    expect(await credentials.readAccessToken(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class NativeLessonService extends FixtureLearningService {
  String response = 'mistake';
  @override
  Future<AttemptResult> submit({
    required String sessionId,
    required String attemptId,
    required String instanceId,
    required int revision,
    required String idempotencyKey,
    required Answer answer,
  }) async => AttemptResult.fromJson(await fixture(response));
}

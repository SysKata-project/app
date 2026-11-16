import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:syskata/app/app.dart';
import 'package:syskata/core/storage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
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

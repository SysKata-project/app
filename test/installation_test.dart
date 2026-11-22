import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syskata/core/authentication.dart';
import 'package:syskata/features/installation.dart';

import 'authentication_test.dart' show MemoryVault, FakeIdentity;

void main() {
  testWidgets(
    'first install saves server settings and supports changing clusters',
    (tester) async {
      final vault = MemoryVault();
      final auth = Authentication(vault, FakeIdentity(), (_) async {});
      await auth.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: ListenableBuilder(
            listenable: auth,
            builder: (context, _) => SetupScreen(auth: auth),
          ),
        ),
      );
      expect(find.text('Choose your learning server'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).at(0),
        'http://api.example',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'https://identity.example/realms/syskata',
      );
      await tester.tap(find.text('Save server settings'));
      await tester.pumpAndSettle();
      expect(auth.installation, isNull);
      await tester.enterText(
        find.byType(TextField).at(0),
        'https://api.example',
      );
      await tester.tap(find.text('Save server settings'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in with your browser'), findsOneWidget);
      expect(auth.installation!.api.host, 'api.example');
      await tester.tap(find.text('Change server'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).at(0),
        'https://next-cluster.example',
      );
      await tester.tap(find.text('Save server settings'));
      await tester.pumpAndSettle();
      expect(auth.installation!.api.host, 'next-cluster.example');
      final restart = Authentication(vault, FakeIdentity(), (_) async {});
      await restart.initialize();
      expect(restart.installation!.api.host, 'next-cluster.example');
    },
  );
}

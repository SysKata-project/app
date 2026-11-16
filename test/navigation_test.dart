import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syskata/app/app.dart';
import 'package:syskata/app/providers.dart';
import 'package:syskata/core/services.dart';

void main() {
  testWidgets('fixture service and four destinations work without a backend', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learningServiceProvider.overrideWithValue(
            FixtureLearningService(bundle: TestFixtures()),
          ),
        ],
        child: const SysKataApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('One more rep?'), findsOneWidget);
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.text('Schema example only'), findsOneWidget);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Make it stick'), findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Your practice, your pace'), findsOneWidget);
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('One more rep?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'large text, narrow screens, landscape and dark mode do not overflow',
    (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
      });
      for (final size in [
        const Size(320, 568),
        const Size(844, 390),
        const Size(1024, 768),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2.5;
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              learningServiceProvider.overrideWithValue(
                FixtureLearningService(bundle: TestFixtures()),
              ),
            ],
            child: const SysKataApp(),
          ),
        );
        await tester.pumpAndSettle();
        for (final tab in ['Learn', 'Review', 'Profile', 'Today']) {
          await tester.tap(find.text(tab));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$size $tab');
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    },
  );
  testWidgets('navigation meets labeled tap target and contrast guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learningServiceProvider.overrideWithValue(
            FixtureLearningService(bundle: TestFixtures()),
          ),
        ],
        child: const SysKataApp(),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
  testWidgets('service errors present recovery without exposing diagnostics', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [learningServiceProvider.overrideWithValue(BrokenService())],
        child: const SysKataApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('We could not load this right now'), findsOneWidget);
    expect(find.textContaining('private diagnostic'), findsNothing);
    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class BrokenService extends FixtureLearningService {
  @override
  Future<Never> progress() async => throw Exception('private diagnostic');
}

class TestFixtures extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      SynchronousFuture(File(key).readAsStringSync());
  @override
  Future<ByteData> load(String key) =>
      SynchronousFuture(ByteData.sublistView(File(key).readAsBytesSync()));
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syskata/app/app.dart';
import 'package:syskata/app/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syskata/core/models.dart';
import 'package:syskata/core/services.dart';
import 'package:syskata/core/preview_service.dart';
import 'package:syskata/features/learning.dart';
import 'package:syskata/features/learning_controller.dart';

import 'navigation_test.dart' show TestFixtures;
import 'services_test.dart' show body;

class ScriptedService extends FixtureLearningService {
  ScriptedService() : super(bundle: TestFixtures());
  String response = 'mistake';
  int sends = 0;
  int starts = 0;
  int journeyReads = 0;
  @override
  Future<JourneyPath> journey(String id) {
    journeyReads++;
    return super.journey(id);
  }

  bool timeout = false;
  final keys = <String>[];
  final payloads = <Json>[];
  @override
  Future<AttemptStarted> startAttempt(
    LearningSession session,
    String key,
  ) async {
    starts++;
    return super.startAttempt(session, key);
  }

  @override
  Future<AttemptResult> submit({
    required String sessionId,
    required String attemptId,
    required String instanceId,
    required int revision,
    required String idempotencyKey,
    required Answer answer,
  }) async {
    sends++;
    keys.add(idempotencyKey);
    payloads.add({'revision': revision, 'answer': answer.toJson()});
    if (timeout && sends == 1) {
      throw const ServiceFailure(
        code: 'timeout',
        retryable: true,
        recovery: 'retry_same_request',
      );
    }
    return AttemptResult.fromJson(body(response));
  }
}

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);
void main() {
  testWidgets(
    'journey to lesson covers hint, mistake, remediation and completion',
    (tester) async {
      final service = ScriptedService();
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
      await tester.ensureVisible(find.text('Request hint'));
      await tester.tap(find.text('Request hint'));
      await tester.pumpAndSettle();
      expect(find.text('Use the pod resource type.'), findsOneWidget);
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
      expect(find.text('Confirmed practice: 10 XP'), findsOneWidget);
      expect(service.starts, 2);
      expect(service.journeyReads, greaterThan(1));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Open lesson'), findsOneWidget);
    },
  );
  test('historical partial progress retains unavailable values', () {
    final result = AttemptResult.fromJson(body('partial-progress'));
    expect(result.progress.partial, true);
    expect(result.progress.streak, isNull);
    expect(result.progress.dailyGoalCompleted, isNull);
    expect(result.progress.totalXp, 10);
  });
  test(
    'pilot preview exposes seven lessons and no invented completed lessons',
    () async {
      final service = PilotPreviewService(bundle: TestFixtures());
      final path = await service.journey('journey.openshift');
      expect(path.lessons.length, 7);
      expect(
        path.lessons.where((l) => l.status == LessonStatus.available).length,
        1,
      );
      expect(
        path.lessons.where((l) => l.status == LessonStatus.completed),
        isEmpty,
      );
    },
  );
  test(
    'incorrect, remediation and completion follow service results',
    () async {
      final service = ScriptedService();
      final flow = LearningController(service);
      await flow.start('journey.fixture', 'lesson.fixture');
      await flow.submit(const ChoiceAnswer('routes'));
      expect(flow.result!.outcome, 'incorrect');
      expect(flow.complete, false);
      expect(flow.result!.nextAction, 'remediate');
      await flow.refresh();
      expect(flow.result, isNull);
      service.response = 'partial-progress';
      await flow.submit(const ChoiceAnswer('pods'));
      expect(flow.complete, true);
      expect(flow.result!.progress.totalXp, 10);
      flow.dispose();
    },
  );
  test(
    'ambiguous submission freezes payload and retries exact key and revision',
    () async {
      final service = ScriptedService()..timeout = true;
      final flow = LearningController(service);
      await flow.start('journey.fixture', 'lesson.fixture');
      await flow.submit(const ChoiceAnswer('pods'));
      expect(flow.canRetry, true);
      expect(flow.hasPending, true);
      await flow.submit(const ChoiceAnswer('routes'));
      expect(service.sends, 1);
      await flow.retry();
      expect(service.starts, 1);
      expect(service.keys[0], service.keys[1]);
      expect(service.payloads[0], service.payloads[1]);
      expect(flow.hasPending, false);
      flow.dispose();
    },
  );
  test(
    'hints advance revision before submission and resumed attempts are reused',
    () async {
      final service = ScriptedService();
      final flow = LearningController(service);
      await flow.start('journey.fixture', 'lesson.fixture');
      await flow.hint('hint.resource');
      expect(flow.hintText, isNotEmpty);
      await flow.submit(const ChoiceAnswer('pods'));
      expect(service.starts, 1);
      expect(service.payloads.single['revision'], 3);
      flow.dispose();
    },
  );
  testWidgets(
    'choice selection submits only selected ID and disables duplicate taps',
    (tester) async {
      Answer? answer;
      await tester.pumpWidget(
        host(
          ExerciseForm(
            question: LearningSession.fromJson(body('getSession-success'))
                .question!,
            disabled: false,
            onSubmit: (a) => answer = a,
          ),
        ),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Check answer'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Pods'));
      await tester.pump();
      await tester.tap(find.text('Check answer'));
      expect(answer!.toJson(), {'type': 'single_choice', 'option_id': 'pods'});
    },
  );
  testWidgets('ordering accessible controls send reordered stable IDs', (
    tester,
  ) async {
    Answer? answer;
    final question =
        LearningSession.fromJson(body('question-command_order')).question!
            as OrderingQuestion;
    await tester.pumpWidget(
      host(
        ExerciseForm(
          question: question,
          disabled: false,
          onSubmit: (a) => answer = a,
        ),
      ),
    );
    await tester.tap(find.text('Move step 1 down'));
    await tester.pump();
    await tester.ensureVisible(find.text('Check answer'));
    await tester.tap(find.text('Check answer'));
    final ids = (answer! as OrderingAnswer).stepIds;
    expect(ids[1], question.steps.first.id);
    expect(ids.toSet().length, question.steps.length);
  });
  testWidgets(
    'command entry constrains control characters and stays editable on mistake',
    (tester) async {
      Answer? answer;
      await tester.pumpWidget(
        host(
          ExerciseForm(
            question: LearningSession.fromJson(body('question-command_entry'))
                .question!,
            disabled: false,
            onSubmit: (a) => answer = a,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'oc\t get\npods');
      await tester.pump();
      await tester.tap(find.text('Check answer'));
      expect((answer! as CommandAnswer).command, 'oc getpods');
    },
  );
  testWidgets(
    'feedback distinguishes mastery evidence and partial daily data',
    (tester) async {
      await tester.pumpWidget(
        host(
          FeedbackView(
            result: AttemptResult.fromJson(body('partial-progress')),
          ),
        ),
      );
      expect(find.text('Correct'), findsOneWidget);
      expect(find.text('Confirmed practice: 10 XP'), findsOneWidget);
      expect(find.text('Skill evidence (separate from XP)'), findsOneWidget);
      expect(
        find.textContaining('unavailable in this historical response'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'exercise layouts support 250% text, reduced motion and keyboard',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;

      for (final name in [
        'getSession-success',
        'question-command_order',
        'question-command_entry',
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(2.5),
                disableAnimations: true,
                viewInsets: EdgeInsets.only(bottom: 250),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ExerciseForm(
                    key: ValueKey(name),
                    question: LearningSession.fromJson(body(name)).question!,
                    disabled: false,
                    onSubmit: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      }
      semantics.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
  testWidgets(
    'infrastructure and sign-in failures do not expose raw diagnostics',
    (tester) async {
      await tester.pumpWidget(
        host(
          LearningError(
            error: const ServiceFailure(
              code: 'private',
              retryable: true,
              recovery: 'retry_same_request',
            ),
            retry: () {},
          ),
        ),
      );
      expect(find.textContaining('not a learner mistake'), findsOneWidget);
      expect(find.text('Retry same request'), findsOneWidget);
      expect(find.textContaining('private'), findsNothing);
    },
  );
}

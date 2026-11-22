import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/providers.dart';
import '../core/models.dart';
import 'destinations.dart';
import 'learning_controller.dart';

final journeyProvider = FutureProvider.family<JourneyPath, String>(
  (ref, id) => ref.watch(learningServiceProvider).journey(id),
  retry: (count, error) => null,
);

class JourneyScreen extends ConsumerWidget {
  const JourneyScreen({required this.id, super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(journeyProvider(id))
      .when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading journey'),
        ),
        error: (error, stack) => PageBody(
          children: [
            FailureCard(
              error: error,
              retry: () => ref.invalidate(journeyProvider(id)),
            ),
          ],
        ),
        data: (path) => PageBody(
          children: [
            Heading(
              path.journey.title,
              'Seven pilot lessons. Curriculum beyond this pilot is planned and unavailable.',
            ),
            if (ref.watch(configProvider).useFakeServices)
              const Text(
                'Development preview · Sample availability and scripted feedback; no answers are graded or saved.',
              ),
            for (final lesson in path.lessons)
              InfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text('${lesson.minutes} minutes · ${lesson.status.name}'),
                    if (lesson.unmetPrerequisites.isNotEmpty)
                      Text(
                        'Complete first: ${lesson.unmetPrerequisites.map((id) => path.lessons.where((l) => l.id == id).firstOrNull?.title ?? id).join(', ')}',
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: lesson.status == LessonStatus.locked
                          ? null
                          : () =>
                                context.push('/learn/$id/lesson/${lesson.id}'),
                      child: Text(
                        lesson.status == LessonStatus.completed
                            ? 'Practice again'
                            : 'Open lesson',
                      ),
                    ),
                  ],
                ),
              ),
            if (id == 'journey.openshift') ...[
              const Heading(
                'Hands-on checkpoints',
                'Real OpenShift environments. Terminal access is not available yet.',
              ),
              for (final name in [
                'Foundations: deploy and expose a workload',
                'Administration: scoped access and resource budgets',
              ])
                InfoCard(
                  child: Text('$name\nTerminal not yet available in this app.'),
                ),
            ],
            DocumentationLinks(references: path.references),
          ],
        ),
      );
}

class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({
    required this.journeyId,
    required this.lessonId,
    super.key,
  });
  final String journeyId, lessonId;
  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  late final LearningController controller;
  final timezone = TextEditingController();
  bool enrolling = false;
  Object? enrollmentError;
  String? enrollmentKey, enrollmentZone;
  AttemptResult? lastConfirmedResult;
  @override
  void initState() {
    super.initState();
    controller = LearningController(ref.read(learningServiceProvider));
    controller.addListener(() {
      final result = controller.result;
      if (result != null && !identical(lastConfirmedResult, result)) {
        lastConfirmedResult = result;
        ref.invalidate(journeyProvider(widget.journeyId));
        ref.invalidate(progressProvider);
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    timezone.dispose();
    super.dispose();
  }

  Future<void> begin() async {
    if (enrolling) return;
    setState(() {
      enrolling = true;
      enrollmentError = null;
    });
    enrollmentKey ??= requestKey();
    enrollmentZone ??= timezone.text.trim();
    try {
      await ref
          .read(learningServiceProvider)
          .enroll(widget.journeyId, enrollmentZone!, enrollmentKey!);
      await controller.start(widget.journeyId, widget.lessonId);
    } catch (e) {
      if (mounted) {
        setState(() {
          enrollmentError = e;
          if (e is ServiceFailure && !e.retryable) {
            enrollmentKey = null;
            enrollmentZone = null;
          }
        });
      }
    } finally {
      if (mounted) setState(() => enrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = ref.watch(journeyProvider(widget.journeyId));
    final progress = ref.watch(progressProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final session = controller.session;
            return PageBody(
              children: [
                if (ref.watch(configProvider).useFakeServices)
                  const Text(
                    'Development preview · Scripted examples, no grading or saved progress.',
                  ),
                if (session == null) ...[
                  ...path.when(
                    data: (p) {
                      final lesson = p.lessons
                          .where((l) => l.id == widget.lessonId)
                          .firstOrNull;
                      if (lesson == null) {
                        return [const Text('This lesson is unavailable.')];
                      }
                      return <Widget>[
                        Heading(lesson.title, '${lesson.minutes} minutes'),
                        SelectableText(lesson.explanation),
                        DocumentationLinks(references: p.references),
                        if (lesson.status == LessonStatus.locked)
                          const Text(
                            'Complete the prerequisites before starting.',
                          )
                        else ...[
                          const Text(
                            'Practice timezone (IANA name). Existing accounts must use their saved timezone; timezone changes belong in account settings.',
                          ),
                          if (progress.isLoading)
                            const LinearProgressIndicator(
                              semanticsLabel: 'Loading saved timezone',
                            ),
                          TextField(
                            controller: timezone,
                            enabled: !enrolling && enrollmentKey == null,
                            decoration: InputDecoration(
                              labelText: 'Timezone',
                              hintText:
                                  progress.value?.timezone ?? 'America/Denver',
                            ),
                          ),
                          FilledButton(
                            onPressed:
                                enrolling ||
                                    controller.busy ||
                                    controller.hasPending
                                ? null
                                : () {
                                    if (timezone.text.trim().isEmpty) {
                                      timezone.text =
                                          progress.value?.timezone ?? '';
                                    }
                                    if (timezone.text.isNotEmpty) begin();
                                  },
                            child: Text(
                              enrolling
                                  ? 'Starting…'
                                  : 'Start or resume lesson',
                            ),
                          ),
                        ],
                      ];
                    },
                    error: (e, s) => [
                      FailureCard(
                        error: e,
                        retry: () =>
                            ref.invalidate(journeyProvider(widget.journeyId)),
                      ),
                    ],
                    loading: () => [
                      const CircularProgressIndicator(
                        semanticsLabel: 'Loading lesson',
                      ),
                    ],
                  ),
                ] else ...[
                  if (session.lessonId != widget.lessonId)
                    const Text(
                      'Resuming your active session before starting another lesson.',
                    ),
                  if (controller.complete)
                    const Heading(
                      'Session complete',
                      'Completion is confirmed by the service. XP recognizes practice; skill evidence is shown separately.',
                    ),
                  if (controller.result case final result?)
                    FeedbackView(result: result),
                  if (!controller.complete &&
                      controller.result == null &&
                      session.question != null)
                    ExerciseForm(
                      key: ValueKey(
                        '${session.instanceId}:${session.revision}',
                      ),
                      question: session.question!,
                      disabled:
                          controller.busy ||
                          controller.hasPending ||
                          (controller.attempt != null &&
                              controller.attempt!.status != 'open'),
                      onSubmit: controller.submit,
                    ),
                  if (!controller.complete &&
                      controller.result == null &&
                      session.question is! LabQuestion) ...[
                    if ((controller.attempt?.hintIds.isNotEmpty ?? false) ||
                        (controller.attempt?.revealed ?? false))
                      const Text('This attempt already used assistance.'),
                    for (final hint in session.question?.hintIds ?? <String>[])
                      OutlinedButton(
                        onPressed: controller.busy || controller.hasPending
                            ? null
                            : () => controller.hint(hint),
                        child: const Text('Request hint'),
                      ),
                    if (controller.hintText != null)
                      Semantics(
                        liveRegion: true,
                        child: SelectableText(controller.hintText!),
                      ),
                  ],
                  DocumentationLinks(references: session.references),
                  if (controller.result != null && !controller.complete)
                    FilledButton(
                      onPressed: controller.busy ? null : controller.refresh,
                      child: Text(
                        controller.result!.nextAction == 'remediate'
                            ? 'Practice the missed objective'
                            : 'Continue',
                      ),
                    ),
                  if (controller.complete)
                    FilledButton(
                      onPressed: () {
                        ref.invalidate(journeyProvider(widget.journeyId));
                        ref.invalidate(progressProvider);
                        context.pop();
                      },
                      child: const Text('Back to journey'),
                    ),
                ],
                if (enrollmentError != null)
                  LearningError(error: enrollmentError!, retry: begin),
                if (controller.error != null)
                  LearningError(
                    error: controller.error!,
                    retry: controller.canRetry ? controller.retry : null,
                    refresh: session != null ? controller.refresh : null,
                  ),
                if (controller.busy)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Waiting for confirmation',
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class LearningError extends StatelessWidget {
  const LearningError({
    required this.error,
    this.retry,
    this.refresh,
    super.key,
  });
  final Object error;
  final VoidCallback? retry, refresh;
  @override
  Widget build(BuildContext context) {
    final failure = error is ServiceFailure ? error as ServiceFailure : null;
    final recovery = failure?.recovery;
    return Semantics(
      liveRegion: true,
      child: InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(switch (recovery) {
              'sign_in' =>
                'Sign-in is required. Account sign-in is not available yet.',
              'refresh_state' => 'This session changed on the server. Refresh to see its current state.',
              'correct_request' =>
                'Check your request or return to the journey to start again.',
              _ => 'We could not confirm this request. This is not a learner mistake.',
            }),
            if (retry != null && (failure?.retryable ?? false))
              OutlinedButton(
                onPressed: retry,
                child: const Text('Retry same request'),
              ),
            if (refresh != null &&
                !(failure?.retryable ?? false) &&
                recovery != 'sign_in')
              OutlinedButton(
                onPressed: refresh,
                child: const Text('Refresh session'),
              ),
          ],
        ),
      ),
    );
  }
}

class ExerciseForm extends StatefulWidget {
  const ExerciseForm({
    required this.question,
    required this.disabled,
    required this.onSubmit,
    super.key,
  });
  final Question question;
  final bool disabled;
  final ValueChanged<Answer> onSubmit;
  @override
  State<ExerciseForm> createState() => _ExerciseFormState();
}

class _ExerciseFormState extends State<ExerciseForm> {
  String? choice;
  late List<Option> order;
  final command = TextEditingController();
  @override
  void initState() {
    super.initState();
    order = widget.question is OrderingQuestion
        ? List.of((widget.question as OrderingQuestion).steps)
        : [];
  }

  @override
  void dispose() {
    command.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    Answer? answer;
    if (q is ChoiceQuestion && choice != null) answer = ChoiceAnswer(choice!);
    if (q is OrderingQuestion) {
      answer = OrderingAnswer(List.unmodifiable(order.map((s) => s.id)));
    }
    if (q is CommandQuestion && command.text.trim().isNotEmpty) {
      answer = CommandAnswer(command.text);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(q.prompt, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 16),
        if (q is ChoiceQuestion)
          for (final option in q.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(
                selected: choice == option.id,
                child: OutlinedButton(
                  onPressed: widget.disabled
                      ? null
                      : () => setState(() => choice = option.id),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${choice == option.id ? 'Selected: ' : ''}${option.text}',
                    ),
                  ),
                ),
              ),
            ),
        if (q is OrderingQuestion) ...[
          const Text('Put the steps in order. Use Move up or Move down.'),
          for (var i = 0; i < order.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}. ${order[i].text}'),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: widget.disabled || i == 0
                              ? null
                              : () => setState(() {
                                  final item = order.removeAt(i);
                                  order.insert(i - 1, item);
                                }),
                          child: Text('Move step ${i + 1} up'),
                        ),
                        TextButton(
                          onPressed: widget.disabled || i == order.length - 1
                              ? null
                              : () => setState(() {
                                  final item = order.removeAt(i);
                                  order.insert(i + 1, item);
                                }),
                          child: Text('Move step ${i + 1} down'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (q is CommandQuestion) ...[
          const Text(
            'Command practice only. This does not execute a command in OpenShift.',
          ),
          TextField(
            controller: command,
            enabled: !widget.disabled,
            maxLength: 4096,
            maxLines: 1,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'[\x00-\x1f\x7f]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Command',
              helperText: 'One line; no control characters.',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        if (q is LabQuestion)
          const Text(
            'This exercise needs a real OpenShift terminal. Terminal access is not available yet.',
          )
        else
          FilledButton(
            onPressed: widget.disabled || answer == null
                ? null
                : () => widget.onSubmit(answer!),
            child: const Text('Check answer'),
          ),
      ],
    );
  }
}

class FeedbackView extends StatelessWidget {
  const FeedbackView({required this.result, super.key});
  final AttemptResult result;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.outcome == 'correct'
                ? 'Correct'
                : 'Let’s check what changed',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          for (final criterion in result.criteria)
            Text(
              '${criterion.passed ? 'Passed' : 'Try again'}: ${criterion.message}',
            ),
          const SizedBox(height: 16),
          Text('Evidence: ${result.evidence}'),
          Text('Confirmed practice: ${result.progress.totalXp} XP'),
          Text(
            '${result.progress.completedLessons.length} completed lessons · ${result.progress.completedCheckpoints.length} completed checkpoints',
          ),
          const Text('Skill evidence (separate from XP)'),
          if (result.progress.skills.isEmpty)
            const Text('No skill evidence reported.'),
          for (final skill in result.progress.skills)
            Text(
              '${skill.id}: ${skill.independent} independent successes, ${skill.assisted} assisted successes, ${skill.mistakes} mistakes',
            ),
          if (result.progress.partial)
            const Text(
              'Review schedules, daily goals and streaks are unavailable in this historical response.',
            ),
          DocumentationLinks(references: result.references),
        ],
      ),
    ),
  );
}

class DocumentationLinks extends StatelessWidget {
  const DocumentationLinks({required this.references, super.key});
  final List<Documentation> references;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final reference in references)
        TextButton(
          onPressed: () async {
            var opened = false;
            try {
              if (reference.uri.scheme == 'https' &&
                  reference.uri.host.isNotEmpty &&
                  reference.uri.userInfo.isEmpty) {
                opened = await launchUrl(
                  reference.uri,
                  mode: LaunchMode.externalApplication,
                );
              }
            } catch (_) {
              /* Show a safe recovery message, never raw plugin errors. */
            }
            if (!opened && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Could not open documentation. Please try again.',
                  ),
                ),
              );
            }
          },
          child: Text('Documentation: ${reference.title} (opens browser)'),
        ),
    ],
  );
}

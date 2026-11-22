import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syskata/core/models.dart';
import 'package:syskata/core/services.dart';
import 'package:syskata/core/storage.dart';
import 'package:syskata/features/learning_controller.dart';

class MemoryJournal implements RecoveryJournal {
  final rows = <String, Json>{};
  bool fail = false;
  @override
  Future<Json?> load(String accountId) async => rows[accountId] == null
      ? null
      : object(jsonDecode(jsonEncode(rows[accountId])));
  @override
  Future<void> write(String accountId, Json payload) async {
    if (fail) throw StateError('disk full');
    rows[accountId] = object(jsonDecode(jsonEncode(payload)));
  }

  @override
  Future<void> clearAccount(String accountId) async {
    rows.remove(accountId);
  }
}

class RecoveryService extends FixtureLearningService {
  RecoveryService(this.journal);
  final MemoryJournal journal;
  bool loseResponse = false, stale = false;
  int submissions = 0, reads = 0;
  final requests = <Json>[];
  @override
  Future<LearningSession> session(String id) async {
    reads++;
    return super.session(id);
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
    submissions++;
    final saved = object((await journal.load('account'))!['operation']);
    expect(saved['key'], idempotencyKey);
    expect(saved['answer'], answer.toJson());
    requests.add({
      'key': idempotencyKey,
      'answer': answer.toJson(),
      'revision': revision,
      'attempt': attemptId,
      'instance': instanceId,
    });
    if (stale) {
      throw const ServiceFailure(
        code: 'stale_revision',
        retryable: false,
        recovery: 'refresh_state',
      );
    }
    if (loseResponse) {
      throw const ServiceFailure(
        code: 'timeout',
        retryable: true,
        recovery: 'retry_same_request',
      );
    }
    return super.submit(
      sessionId: sessionId,
      attemptId: attemptId,
      instanceId: instanceId,
      revision: revision,
      idempotencyKey: idempotencyKey,
      answer: answer,
    );
  }
}

class ExistingSessionService extends FixtureLearningService {
  int attemptCreations = 0;
  @override
  Future<LearningSession> startSession(
    String journeyId,
    String lessonId,
    String key,
  ) => session('existing-session');
  @override
  Future<LearningSession> session(String id) async {
    final data = await fixture('getSession-success');
    data['session_id'] = 'existing-session';
    data['current_attempt'] = (await fixture(
      'startAttempt-success',
    ))['attempt'];
    return LearningSession.fromJson(data);
  }

  @override
  Future<AttemptStarted> startAttempt(
    LearningSession session,
    String key,
  ) async {
    attemptCreations++;
    return super.startAttempt(session, key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'lost response and restart replay exact persisted payload and key',
    () async {
      final journal = MemoryJournal();
      // The same durable store is observed by the network fake.
      final backend = RecoveryService(journal);
      final first = LearningController(
        backend,
        journal: journal,
        accountId: 'account',
      );
      await first.start('journey.openshift', 'lesson');
      backend.loseResponse = true;
      await first.submit(const ChoiceAnswer('pods'));
      expect(first.hasPending, isTrue);
      expect(first.result, isNull);
      first.dispose();
      backend.loseResponse = false;
      final restarted = LearningController(
        backend,
        journal: journal,
        accountId: 'account',
      );
      await restarted.restore();
      expect(backend.requests, hasLength(2));
      expect(backend.requests[0], backend.requests[1]);
      expect(restarted.hasPending, isFalse);
      expect(restarted.result, isNotNull);
    },
  );
  test(
    'storage failure prevents transmission and reconnect preserves intent',
    () async {
      final journal = MemoryJournal();
      final backend = RecoveryService(journal);
      final controller = LearningController(
        backend,
        journal: journal,
        accountId: 'account',
      );
      await controller.start('journey.openshift', 'lesson');
      journal.fail = true;
      await controller.submit(const CommandAnswer('oc get pods'));
      expect(backend.submissions, 0);
      expect(controller.canRetry, isTrue);
      journal.fail = false;
      await controller.retry();
      expect(backend.submissions, 1);
      expect(controller.hasPending, isFalse);
    },
  );
  test('definitive stale rejection reconciles before another answer', () async {
    final journal = MemoryJournal();
    final backend = RecoveryService(journal)..stale = true;
    final controller = LearningController(
      backend,
      journal: journal,
      accountId: 'account',
    );
    await controller.start('journey.openshift', 'lesson');
    await controller.submit(const ChoiceAnswer('pods'));
    expect(controller.canRetry, isFalse);
    await controller.submit(const ChoiceAnswer('routes'));
    expect(backend.submissions, 1);
    final reads = backend.reads;
    await controller.refresh();
    expect(backend.reads, greaterThan(reads));
    expect(controller.hasPending, isFalse);
  });
  test(
    'second device starts with no cache and resumes the server active attempt',
    () async {
      final service = ExistingSessionService();
      final controller = LearningController(
        service,
        journal: MemoryJournal(),
        accountId: 'second-device',
      );
      await controller.restore();
      expect(controller.session, isNull);
      await controller.start('journey.openshift', 'another-lesson');
      expect(controller.session!.id, 'existing-session');
      expect(controller.attempt, isNotNull);
      await controller.submit(const ChoiceAnswer('pods'));
      expect(service.attemptCreations, 0);
      expect(controller.result, isNotNull);
    },
  );
  test(
    'background resume reads server and account switch rejects late writes',
    () async {
      final journal = MemoryJournal();
      final backend = RecoveryService(journal);
      var current = true;
      final scoped = ScopedRecoveryJournal(journal, () => current);
      final controller = LearningController(
        backend,
        journal: scoped,
        accountId: 'account',
      );
      await controller.start('journey.openshift', 'lesson');
      final reads = backend.reads;
      await controller.foreground();
      expect(backend.reads, greaterThan(reads));
      expect(await journal.load('other-account'), isNull);
      current = false;
      await journal.clearAccount('account');
      await controller.submit(const ChoiceAnswer('pods'));
      expect(backend.submissions, 0);
      expect(await journal.load('account'), isNull);
    },
  );
}

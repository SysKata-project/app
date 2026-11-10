import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syskata/core/models.dart';
import 'package:syskata/core/services.dart';

Json fixture(String name) =>
    object(jsonDecode(File('assets/fixtures/$name.json').readAsStringSync()));
Json body(String name) => object(object(fixture(name)['response'])['body']);
HttpLearningService service(http.Client client) => HttpLearningService(
  client: client,
  origin: Uri.parse('https://api.example.invalid'),
  accessToken: () async => 'test-only',
);
void main() {
  test('typed models decode all selected successful upstream fixtures', () {
    expect(
      Catalog.fromJson(body('listJourneys-success')).journeys.single.id,
      'journey.fixture',
    );
    expect(
      JourneyPath.fromJson(body('getJourney-success')).lessons,
      isNotEmpty,
    );
    expect(Progress.fromJson(body('getProgress-success')).totalXp, 0);
    expect(
      LearningSession.fromJson(body('getSession-success')).question,
      isA<ChoiceQuestion>(),
    );
    expect(
      LearningSession.fromJson(body('question-command_order')).question,
      isA<OrderingQuestion>(),
    );
    expect(
      LearningSession.fromJson(body('question-command_entry')).question,
      isA<CommandQuestion>(),
    );
    expect(LabSession.fromJson(body('getLab-success')).id, 'lab-1');
    expect(
      Assessment.fromJson(body('getAssessment-success')).status,
      'pending',
    );
    final result = AttemptResult.fromJson(body('submitAttempt-success'));
    expect(result.criteria, isNotEmpty);
    expect(result.nextAction, isNotEmpty);
    expect(AttemptResult.fromJson(body('mistake')).outcome, 'incorrect');
    expect(
      AttemptResult.fromJson(body('duplicate-submission')).progress.totalXp,
      result.progress.totalXp,
    );
  });
  test('all bundled lab question fixtures have a typed variant', () {
    var count = 0;
    for (final file in Directory(
      'assets/fixtures',
    ).listSync().whereType<File>()) {
      final envelope = object(jsonDecode(file.readAsStringSync()));
      final data = object(object(envelope['response'])['body']);
      if (data['current_instance'] != null &&
          object(object(data['current_instance'])['question'])['type'] ==
              'lab_task') {
        count++;
        expect(LearningSession.fromJson(data).question, isA<LabQuestion>());
      }
    }
    expect(count, greaterThan(0));
  });
  test('unknown content versions and question types fail closed', () {
    final data = body('listJourneys-success');
    object(data['versions'])['schema_version'] = '99.0.0';
    expect(() => Catalog.fromJson(data), throwsFormatException);
    expect(() => Question.fromJson({'type': 'unknown'}), throwsFormatException);
  });
  test(
    'HTTP adapter authenticates and preserves mutation payload and retry key',
    () async {
      final api = service(
        MockClient((request) async {
          expect(
            request.url.path,
            '/v1/learning-sessions/session-1/attempts/attempt-1/submission',
          );
          expect(request.method, 'POST');
          expect(request.followRedirects, false);
          expect(request.headers['Authorization'], 'Bearer test-only');
          expect(request.headers['Idempotency-Key'], 'persisted-key');
          expect(jsonDecode(request.body), {
            'session_revision': 2,
            'exercise_instance_id': 'instance-1',
            'answer': {'type': 'single_choice', 'option_id': 'pods'},
          });
          return http.Response(jsonEncode(body('submitAttempt-success')), 200);
        }),
      );
      final result = await api.submit(
        sessionId: 'session-1',
        attemptId: 'attempt-1',
        instanceId: 'instance-1',
        revision: 2,
        idempotencyKey: 'persisted-key',
        answer: const ChoiceAnswer('pods'),
      );
      expect(result.outcome, 'correct');
    },
  );
  test('reads route to their contracted paths', () async {
    final cases = {
      '/v1/journeys': 'listJourneys-success',
      '/v1/me/journeys/journey.fixture': 'getJourney-success',
      '/v1/me/progress': 'getProgress-success',
      '/v1/learning-sessions/session-1': 'getSession-success',
      '/v1/lab-sessions/lab-1': 'getLab-success',
      '/v1/assessments/assessment-1': 'getAssessment-success',
    };
    final seen = <String>[];
    final api = service(
      MockClient((request) async {
        seen.add(request.url.path);
        expect(request.method, 'GET');
        return http.Response(jsonEncode(body(cases[request.url.path]!)), 200);
      }),
    );
    await api.catalog();
    await api.journey('journey.fixture');
    await api.progress();
    await api.session('session-1');
    await api.lab('lab-1');
    await api.assessment('assessment-1');
    expect(seen.toSet(), cases.keys.toSet());
  });
  test('stale state and infrastructure errors preserve server recovery instructions', () async {
    for (final name in [
      'stale-revision',
      'infrastructure-failure',
      'expired-lab',
    ]) {
      final envelope = fixture(name);
      final response = object(envelope['response']);
      final api = service(
        MockClient(
          (_) async => http.Response(
            jsonEncode(response['body']),
            response['status'] as int,
          ),
        ),
      );
      final expected = object(object(response['body'])['error']);
      await expectLater(
        api.progress(),
        throwsA(
          isA<ServiceFailure>()
              .having((e) => e.code, 'code', expected['code'])
              .having((e) => e.retryable, 'retryable', expected['retryable'])
              .having((e) => e.recovery, 'recovery', expected['recovery']),
        ),
      );
    }
  });
  test('network failure does not retry a mutation automatically', () async {
    var count = 0;
    final api = service(
      MockClient((_) async {
        count++;
        throw http.ClientException('private diagnostic');
      }),
    );
    await expectLater(
      api.submit(
        sessionId: 's',
        attemptId: 'a',
        instanceId: 'i',
        revision: 1,
        idempotencyKey: 'stable',
        answer: const CommandAnswer('oc get pods'),
      ),
      throwsA(
        isA<ServiceFailure>().having(
          (e) => e.recovery,
          'recovery',
          'retry_same_request',
        ),
      ),
    );
    expect(count, 1);
  });
  test('missing credentials never sends a request', () async {
    final api = HttpLearningService(
      client: MockClient((_) async => throw StateError('must not send')),
      origin: Uri.parse('https://api.example.invalid'),
      accessToken: () async => null,
    );
    await expectLater(
      api.catalog(),
      throwsA(
        isA<ServiceFailure>().having((e) => e.code, 'code', 'unauthenticated'),
      ),
    );
  });
  test('invalid response and redirects are redacted', () async {
    for (final status in [200, 302, 502]) {
      final api = service(
        MockClient(
          (_) async => http.Response('<html>private diagnostic</html>', status),
        ),
      );
      await expectLater(
        api.catalog(),
        throwsA(
          isA<ServiceFailure>().having(
            (e) => e.toString(),
            'redacted',
            isNot(contains('private')),
          ),
        ),
      );
    }
  });
  test('timeouts include response consumption', () async {
    final api = HttpLearningService(
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response('{}', 200);
      }),
      origin: Uri.parse('https://api.example.invalid'),
      accessToken: () async => 'test',
      timeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      api.catalog(),
      throwsA(isA<ServiceFailure>().having((e) => e.code, 'code', 'timeout')),
    );
  });
  test('rejects insecure origins and path injection', () async {
    expect(
      () => HttpLearningService(
        client: MockClient((_) async => http.Response('{}', 200)),
        origin: Uri.parse('http://example.invalid'),
        accessToken: () async => null,
      ),
      throwsArgumentError,
    );
    await expectLater(
      service(MockClient((_) async => http.Response('{}', 200)))
          .session('../me'),
      throwsArgumentError,
    );
  });
}

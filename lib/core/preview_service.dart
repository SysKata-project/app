import 'dart:convert';

import 'models.dart';
import 'services.dart';

/// Development-only public draft projection and scripted contract responses.
/// No answer evaluation, reward calculation or learner persistence happens here.
class PilotPreviewService extends FixtureLearningService {
  PilotPreviewService({super.bundle});
  Json? _current;
  int _position = 0;
  List<Json> _questions = [];
  Future<Json> _content() async => object(
    jsonDecode(await bundle.loadString('assets/preview/learner.json')),
  );
  @override
  Future<Catalog> catalog() async {
    final content = await _content();
    return Catalog.fromJson({
      'versions': {
        'schema_version': content['schema_version'],
        'bundle_version': content['bundle_version'],
        'policy_version': '1.0.0',
      },
      'journeys': objects(content['entities'])
          .where((e) => e['kind'] == 'journey')
          .toList(),
    });
  }

  @override
  Future<JourneyPath> journey(String id) async {
    final content = await _content();
    final entities = objects(content['entities']);
    final lessons = entities.where((e) => e['kind'] == 'lesson').toList();
    return JourneyPath.fromJson({
      'versions': {
        'schema_version': content['schema_version'],
        'bundle_version': content['bundle_version'],
        'policy_version': '1.0.0',
      },
      'journey': entities.firstWhere((e) => e['id'] == id),
      'references': entities.where((e) => e['kind'] == 'reference').toList(),
      'lessons': [
        for (var i = 0; i < lessons.length; i++)
          {
            'lesson': lessons[i],
            'status': i == 0 ? 'available' : 'locked',
            'unmet_prerequisite_ids': i == 0
                ? <String>[]
                : [lessons[i - 1]['id']],
          },
      ],
    });
  }

  @override
  Future<LearningSession> startSession(
    String journeyId,
    String lessonId,
    String key,
  ) async {
    final content = await _content();
    final entities = objects(content['entities']);
    final lesson = entities.firstWhere((e) => e['id'] == lessonId);
    _questions = strings(lesson['exercise_ids'])
        .map((id) => entities.firstWhere((e) => e['id'] == id))
        .toList();
    _position = 0;
    _current = await fixture('startSession-success');
    _current!['lesson_id'] = lessonId;
    _current!['journey_id'] = journeyId;
    _current!['versions'] = {
      'schema_version': content['schema_version'],
      'bundle_version': content['bundle_version'],
      'policy_version': '1.0.0',
    };
    _current!['references'] = entities
        .where((e) => e['kind'] == 'reference')
        .toList();
    _setQuestion();
    return LearningSession.fromJson(_current!);
  }

  void _setQuestion() {
    object(_current!['current_instance'])['question'] = _questions[_position];
    object(_current!['current_instance'])['exercise_instance_id'] =
        'preview-$_position';
    _current!['current_attempt'] = null;
  }

  @override
  Future<LearningSession> session(String id) async =>
      LearningSession.fromJson(_current!);
  @override
  Future<AttemptStarted> startAttempt(
    LearningSession session,
    String key,
  ) async {
    final data = await fixture('startAttempt-success');
    data['session_revision'] = session.revision + 1;
    return AttemptStarted.fromJson(data);
  }

  @override
  Future<HintResult> hint(
    String sessionId,
    String attemptId,
    int revision,
    String hintId,
    String key,
  ) async => HintResult.fromJson({
    'text_markdown': 'Preview hint: reread the requested resource and scope. Live hints are supplied by the service.',
    'session_revision': revision + 1,
  });
  @override
  Future<AttemptResult> submit({
    required String sessionId,
    required String attemptId,
    required String instanceId,
    required int revision,
    required String idempotencyKey,
    required Answer answer,
  }) async {
    final data = await fixture('submitAttempt-success');
    data['session_revision'] = revision + 1;
    data['criteria'] = [
      {
        'criterion_id': 'preview',
        'passed': true,
        'explanation': 'Scripted preview response. Your answer was not graded.',
      },
    ];
    data['references'] = _current!['references'];
    data['progress'] = {
      'revision': revision + 1,
      'confirmed_at': '2026-11-22T00:00:00Z',
      'total_xp': 0,
      'completed_lesson_ids': <String>[],
      'completed_checkpoint_ids': <String>[],
      'skills': <Json>[],
      'status': 'partial',
    };
    _position++;
    data['next_action'] = {
      'type': _position == _questions.length ? 'session_complete' : 'continue',
      'session_id': sessionId,
    };
    _current!['revision'] = revision + 1;
    if (_position < _questions.length) _setQuestion();
    return AttemptResult.fromJson(data);
  }
}

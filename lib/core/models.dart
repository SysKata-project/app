typedef Json = Map<String, dynamic>;
Json object(Object? value) => value as Json;
List<Json> objects(Object? value) =>
    (value as List<dynamic>).map(object).toList(growable: false);
List<String> strings(Object? value) => (value as List<dynamic>).cast<String>();

class Versions {
  Versions.fromJson(Json json)
    : schema = json['schema_version'] as String,
      bundle = json['bundle_version'] as String,
      policy = json['policy_version'] as String {
    if (schema != '1.0.0') {
      throw const FormatException('Unsupported content schema');
    }
  }
  final String schema, bundle, policy;
}

class Journey {
  Journey.fromJson(Json json)
    : id = json['id'] as String,
      title = json['title'] as String,
      unitIds = strings(json['unit_ids']);
  final String id, title;
  final List<String> unitIds;
}

class Catalog {
  Catalog.fromJson(Json json)
    : versions = Versions.fromJson(object(json['versions'])),
      journeys = objects(json['journeys'])
          .map(Journey.fromJson)
          .toList(growable: false);
  final Versions versions;
  final List<Journey> journeys;
}

enum LessonStatus { locked, available, completed }

class LessonNode {
  LessonNode.fromJson(Json json)
    : id = object(json['lesson'])['id'] as String,
      title = object(json['lesson'])['title'] as String,
      explanation = object(json['lesson'])['explanation_markdown'] as String,
      minutes = object(json['lesson'])['estimated_minutes'] as int,
      status = LessonStatus.values.byName(json['status'] as String),
      unmetPrerequisites = strings(json['unmet_prerequisite_ids']);
  final String id, title;
  final String explanation;
  final int minutes;
  final LessonStatus status;
  final List<String> unmetPrerequisites;
}

class JourneyPath {
  JourneyPath.fromJson(Json json)
    : versions = Versions.fromJson(object(json['versions'])),
      journey = Journey.fromJson(object(json['journey'])),
      references = objects(json['references'])
          .map(Documentation.fromJson)
          .toList(),
      lessons = objects(json['lessons'])
          .map(LessonNode.fromJson)
          .toList(growable: false);
  final Versions versions;
  final Journey journey;
  final List<LessonNode> lessons;
  final List<Documentation> references;
}

class Progress {
  Progress.fromJson(Json json)
    : revision = json['revision'] as int,
      totalXp = json['total_xp'] as int,
      partial = json['status'] == 'partial',
      skills = objects(json['skills']).map(SkillEvidence.fromJson).toList(),
      completedCheckpoints = strings(json['completed_checkpoint_ids']),
      timezone = json['timezone'] as String?,
      streak = json['current_streak'] as int?,
      dailyGoalCompleted = json['daily_goal_completed'] as bool?,
      confirmedAt = DateTime.parse(json['confirmed_at'] as String),
      completedLessons = strings(json['completed_lesson_ids']);
  final int revision, totalXp;
  final int? streak;
  final bool? dailyGoalCompleted;
  final bool partial;
  final String? timezone;
  final List<SkillEvidence> skills;
  final List<String> completedCheckpoints;
  final DateTime confirmedAt;
  final List<String> completedLessons;
}

class Option {
  Option.fromJson(Json json)
    : id = json['id'] as String,
      text = json['text'] as String;
  final String id, text;
}

sealed class Question {
  Question(Json json)
    : id = json['id'] as String,
      hintIds = strings(json['hint_ids']),
      prompt = json['prompt'] as String;
  final List<String> hintIds;
  final String id, prompt;
  factory Question.fromJson(Json json) => switch (json['type']) {
    'single_choice' => ChoiceQuestion(json),
    'command_order' => OrderingQuestion(json),
    'command_entry' => CommandQuestion(json),
    'lab_task' => LabQuestion(json),
    _ => throw const FormatException('Unsupported exercise type'),
  };
}

class ChoiceQuestion extends Question {
  ChoiceQuestion(super.json)
    : options = objects(json['options'])
          .map(Option.fromJson)
          .toList(growable: false);
  final List<Option> options;
}

class OrderingQuestion extends Question {
  OrderingQuestion(super.json)
    : steps = objects(json['steps'])
          .map(Option.fromJson)
          .toList(growable: false);
  final List<Option> steps;
}

class CommandQuestion extends Question {
  CommandQuestion(super.json);
}

class LabQuestion extends Question {
  LabQuestion(super.json);
}

class LearningSession {
  LearningSession.fromJson(Json json)
    : snapshot = json,
      id = json['session_id'] as String,
      revision = json['revision'] as int,
      status = json['status'] as String,
      lessonId = json['lesson_id'] as String?,
      references = objects(json['references'])
          .map(Documentation.fromJson)
          .toList(),
      attempt = json['current_attempt'] == null
          ? null
          : OpenAttempt.fromJson(object(json['current_attempt'])),
      versions = Versions.fromJson(object(json['versions'])),
      instanceId = json['current_instance'] == null
          ? null
          : object(json['current_instance'])['exercise_instance_id'] as String,
      question = json['current_instance'] == null
          ? null
          : Question.fromJson(
              object(object(json['current_instance'])['question']),
            );
  final Json snapshot;
  final String id, status;
  final String? lessonId;
  final OpenAttempt? attempt;
  final List<Documentation> references;
  final int revision;
  final Versions versions;
  final String? instanceId;
  final Question? question;
}

sealed class Answer {
  const Answer();
  Json toJson();
}

class ChoiceAnswer extends Answer {
  const ChoiceAnswer(this.optionId);
  final String optionId;
  @override
  Json toJson() => {'type': 'single_choice', 'option_id': optionId};
}

class OrderingAnswer extends Answer {
  const OrderingAnswer(this.stepIds);
  final List<String> stepIds;
  @override
  Json toJson() => {'type': 'command_order', 'step_ids': stepIds};
}

class CommandAnswer extends Answer {
  const CommandAnswer(this.command);
  final String command;
  @override
  Json toJson() => {'type': 'command_entry', 'command': command};
}

class CriterionFeedback {
  CriterionFeedback.fromJson(Json json)
    : id = json['criterion_id'] as String,
      passed = json['passed'] as bool,
      message = json['explanation'] as String;
  final String id, message;
  final bool passed;
}

class AttemptResult {
  AttemptResult.fromJson(Json json)
    : attemptId = json['attempt_id'] as String,
      outcome = json['outcome'] as String,
      evidence = json['evidence'] as String,
      references = objects(json['references'])
          .map(Documentation.fromJson)
          .toList(),
      sessionRevision = json['session_revision'] as int,
      progress = Progress.fromJson(object(json['progress'])),
      criteria = objects(json['criteria'])
          .map(CriterionFeedback.fromJson)
          .toList(growable: false),
      nextAction = object(json['next_action'])['type'] as String;
  final String attemptId, outcome, nextAction, evidence;
  final List<Documentation> references;
  final int sessionRevision;
  final Progress progress;
  final List<CriterionFeedback> criteria;
}

class ServiceFailure implements Exception {
  const ServiceFailure({
    required this.code,
    required this.retryable,
    required this.recovery,
    this.correlationId,
    this.currentRevision,
  });
  factory ServiceFailure.fromJson(Json json) => ServiceFailure(
    code: json['code'] as String,
    retryable: json['retryable'] as bool,
    recovery: json['recovery'] as String,
    correlationId: json['correlation_id'] as String,
    currentRevision: json['current_revision'] as int?,
  );
  final String code, recovery;
  final bool retryable;
  final String? correlationId;
  final int? currentRevision;
  // Deliberately omit response bodies and credentials from diagnostics.
  @override
  String toString() => 'ServiceFailure($code)';
}

class LabSession {
  LabSession.fromJson(Json json)
    : id = json['lab_session_id'] as String,
      generation = json['generation'] as int,
      status = json['status'] as String,
      expiresAt = json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      error = json['error'] == null
          ? null
          : ServiceFailure.fromJson(object(json['error']));
  final String id, status;
  final int generation;
  final DateTime? expiresAt;
  final ServiceFailure? error;
}

class Assessment {
  Assessment.fromJson(Json json)
    : id = json['assessment_id'] as String,
      status = json['status'] as String,
      generation = json['generation'] as int,
      result = json['result'] == null
          ? null
          : AttemptResult.fromJson(object(json['result'])),
      error = json['error'] == null
          ? null
          : ServiceFailure.fromJson(object(json['error']));
  final String id, status;
  final int generation;
  final AttemptResult? result;
  final ServiceFailure? error;
}

class Documentation {
  Documentation.fromJson(Json json)
    : title = json['title'] as String,
      uri = Uri.parse(json['url'] as String);
  final String title;
  final Uri uri;
}

class SkillEvidence {
  SkillEvidence.fromJson(Json json)
    : id = json['skill_id'] as String,
      independent = json['independent_successes'] as int,
      assisted = json['assisted_successes'] as int,
      mistakes = json['mistakes'] as int;
  final String id;
  final int independent, assisted, mistakes;
}

class OpenAttempt {
  OpenAttempt.fromJson(Json json)
    : id = json['attempt_id'] as String,
      status = json['status'] as String,
      hintIds = strings(object(json['assistance'])['hint_ids']),
      revealed = object(json['assistance'])['revealed'] as bool;
  final String id, status;
  final List<String> hintIds;
  final bool revealed;
}

class AttemptStarted {
  AttemptStarted.fromJson(Json json)
    : attempt = OpenAttempt.fromJson(object(json['attempt'])),
      revision = json['session_revision'] as int;
  final OpenAttempt attempt;
  final int revision;
}

class HintResult {
  HintResult.fromJson(Json json)
    : text = json['text_markdown'] as String,
      revision = json['session_revision'] as int;
  final String text;
  final int revision;
}

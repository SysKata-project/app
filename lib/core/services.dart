import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

abstract interface class LearningService {
  Future<Catalog> catalog();
  Future<JourneyPath> journey(String id);
  Future<Progress> progress();
  Future<LearningSession> session(String id);
  Future<AttemptResult> submit({
    required String sessionId,
    required String attemptId,
    required String instanceId,
    required int revision,
    required String idempotencyKey,
    required Answer answer,
  });
  Future<LabSession> lab(String id);
  Future<Assessment> assessment(String id);
}

class HttpLearningService implements LearningService {
  HttpLearningService({
    required this.client,
    required this.origin,
    required this.accessToken,
    this.timeout = const Duration(seconds: 20),
  }) {
    if (origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        (origin.path.isNotEmpty && origin.path != '/')) {
      throw ArgumentError('API origin must use HTTPS');
    }
  }
  final http.Client client;
  final Uri origin;
  final Future<String?> Function() accessToken;
  final Duration timeout;
  String _id(String id) {
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(id)) {
      throw ArgumentError('Invalid identifier');
    }
    return id;
  }

  Future<Json> _request(String path, {Json? body, String? key}) async {
    final token = await accessToken();
    if (token == null || token.isEmpty) {
      throw const ServiceFailure(
        code: 'unauthenticated',
        retryable: false,
        recovery: 'sign_in',
      );
    }
    final request = http.Request(
      body == null ? 'GET' : 'POST',
      origin.resolve(path),
    );
    request.followRedirects = false;
    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });
    if (body != null) {
      if (key == null || key.isEmpty) {
        throw ArgumentError('Mutation requires a durable idempotency key');
      }
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Idempotency-Key': key,
      });
      request.body = jsonEncode(body);
    }
    try {
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(timeout);
      if (response.statusCode >= 300 && response.statusCode < 400) {
        throw const ServiceFailure(
          code: 'unexpected_redirect',
          retryable: false,
          recovery: 'contact_support',
        );
      }
      final Json data;
      try {
        data = object(jsonDecode(utf8.decode(response.bodyBytes)));
      } on FormatException {
        throw const ServiceFailure(
          code: 'invalid_response',
          retryable: false,
          recovery: 'contact_support',
        );
      } on TypeError {
        throw const ServiceFailure(
          code: 'invalid_response',
          retryable: false,
          recovery: 'contact_support',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        try {
          throw ServiceFailure.fromJson(object(data['error']));
        } on TypeError {
          throw const ServiceFailure(
            code: 'invalid_response',
            retryable: false,
            recovery: 'contact_support',
          );
        }
      }
      return data;
    } on TimeoutException {
      throw const ServiceFailure(
        code: 'timeout',
        retryable: true,
        recovery: 'retry_same_request',
      );
    } on http.ClientException {
      throw const ServiceFailure(
        code: 'connection_unavailable',
        retryable: true,
        recovery: 'retry_same_request',
      );
    }
  }

  @override
  Future<Catalog> catalog() async =>
      Catalog.fromJson(await _request('/v1/journeys'));
  @override
  Future<JourneyPath> journey(String id) async =>
      JourneyPath.fromJson(await _request('/v1/me/journeys/${_id(id)}'));
  @override
  Future<Progress> progress() async =>
      Progress.fromJson(await _request('/v1/me/progress'));
  @override
  Future<LearningSession> session(String id) async => LearningSession.fromJson(
    await _request('/v1/learning-sessions/${_id(id)}'),
  );
  @override
  Future<LabSession> lab(String id) async =>
      LabSession.fromJson(await _request('/v1/lab-sessions/${_id(id)}'));
  @override
  Future<Assessment> assessment(String id) async =>
      Assessment.fromJson(await _request('/v1/assessments/${_id(id)}'));
  @override
  Future<AttemptResult> submit({
    required String sessionId,
    required String attemptId,
    required String instanceId,
    required int revision,
    required String idempotencyKey,
    required Answer answer,
  }) async => AttemptResult.fromJson(
    await _request(
      '/v1/learning-sessions/${_id(sessionId)}/attempts/${_id(attemptId)}/submission',
      key: idempotencyKey,
      body: {
        'session_revision': revision,
        'exercise_instance_id': instanceId,
        'answer': answer.toJson(),
      },
    ),
  );
}

/// Fixed upstream examples for UI development; no local grading or rewards.
class FixtureLearningService implements LearningService {
  FixtureLearningService({AssetBundle? bundle}) : bundle = bundle ?? rootBundle;
  final AssetBundle bundle;
  Future<Json> fixture(String name) async {
    final envelope = object(
      jsonDecode(await bundle.loadString('assets/fixtures/$name.json')),
    );
    return object(object(envelope['response'])['body']);
  }

  @override
  Future<Catalog> catalog() async =>
      Catalog.fromJson(await fixture('listJourneys-success'));
  @override
  Future<JourneyPath> journey(String id) async =>
      JourneyPath.fromJson(await fixture('getJourney-success'));
  @override
  Future<Progress> progress() async =>
      Progress.fromJson(await fixture('getProgress-success'));
  @override
  Future<LearningSession> session(String id) async =>
      LearningSession.fromJson(await fixture('getSession-success'));
  @override
  Future<LabSession> lab(String id) async =>
      LabSession.fromJson(await fixture('getLab-success'));
  @override
  Future<Assessment> assessment(String id) async =>
      Assessment.fromJson(await fixture('getAssessment-success'));
  @override
  Future<AttemptResult> submit({
    required String sessionId,
    required String attemptId,
    required String instanceId,
    required int revision,
    required String idempotencyKey,
    required Answer answer,
  }) async => AttemptResult.fromJson(await fixture('submitAttempt-success'));
}

import 'dart:math';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/models.dart';
import '../core/services.dart';
import '../core/storage.dart';

String requestKey() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Writes the full intent before network I/O; replays exact keys after interruption.
class LearningController extends ChangeNotifier {
  LearningController(this.service, {this.journal, this.accountId});
  final LearningService service;
  final RecoveryJournal? journal;
  final String? accountId;
  LearningSession? session;
  OpenAttempt? attempt;
  AttemptResult? result;
  int revision = 0;
  bool busy = false;
  Object? error;
  String? hintText;
  Json? _operation;
  bool _disposed = false;
  bool get complete =>
      result?.nextAction == 'session_complete' ||
      session?.status == 'completed';
  bool get canRetry =>
      error is ServiceFailure && (error! as ServiceFailure).retryable;
  bool get hasPending => _operation != null;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _persist() async {
    if (_disposed) {
      throw const ServiceFailure(
        code: 'controller_closed',
        retryable: true,
        recovery: 'retry_same_request',
      );
    }
    if (journal != null && accountId != null) {
      try {
        await journal!.write(accountId!, {
          'session': session?.snapshot,
          'operation': _operation,
        });
      } catch (_) {
        throw const ServiceFailure(
          code: 'storage_unavailable',
          retryable: true,
          recovery: 'retry_same_request',
        );
      }
    }
  }

  Future<void> restore() async {
    if (journal == null || accountId == null || busy) return;
    await _run(() async {
      final saved = await journal!.load(accountId!);
      if (saved == null) return;
      if (saved['session'] != null) {
        _accept(LearningSession.fromJson(object(saved['session'])));
      }
      _operation = saved['operation'] == null
          ? null
          : object(saved['operation']);
      if (_operation != null) {
        await _execute();
      } else if (session != null) {
        _accept(await service.session(session!.id));
        await _persist();
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    _changed();
    try {
      await action();
    } catch (failure) {
      error = failure;
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> _begin(Json operation) async {
    if (busy || hasPending || _disposed) return;
    // A JSON round trip freezes mutable answer collections before persistence.
    _operation = object(jsonDecode(jsonEncode(operation)));
    await _run(() async {
      await _persist();
      await _execute();
    });
  }

  Future<void> retry() async {
    if (hasPending && canRetry) {
      await _run(() async {
        await _persist();
        await _execute();
      });
    }
  }

  Future<void> start(String journey, String lesson) => _begin({
    'kind': 'start',
    'journey': journey,
    'lesson': lesson,
    'key': requestKey(),
  });
  Future<void> enrollAndStart(String journey, String lesson, String timezone) =>
      _begin({
        'kind': 'enroll',
        'journey': journey,
        'lesson': lesson,
        'timezone': timezone,
        'enrollKey': requestKey(),
        'key': requestKey(),
      });
  void _accept(LearningSession value) {
    session = value;
    revision = value.revision;
    attempt = value.attempt;
    result = null;
    hintText = null;
  }

  Future<void> refresh() async {
    if (session == null || busy) return;
    // Never discard ambiguous work in favor of a fresh submission.
    if (hasPending && (error == null || canRetry)) {
      await _run(_execute);
      return;
    }
    await _run(() async {
      final latest = await service.session(session!.id);
      _accept(latest);
      _operation =
          null; // Only explicit reconciliation of a definitive rejection.
      await _persist();
    });
  }

  bool get canRestart {
    final failure = error;
    if (failure is! ServiceFailure || failure.retryable) return false;
    return [
          'expired',
          'unsupported_content',
          'not_found',
        ].contains(failure.code) ||
        (session == null && failure.recovery == 'correct_request');
  }

  Future<void> restart() async {
    if (!canRestart || busy) return;
    await _run(() async {
      session = null;
      attempt = null;
      result = null;
      _operation = null;
      await _persist();
    });
  }

  Future<void> foreground() async {
    if (busy) return;
    if (hasPending) {
      if (error == null || canRetry) await _run(_execute);
    } else {
      await refresh();
    }
  }

  Future<void> submit(Answer answer) async {
    if (session?.instanceId == null || result != null) return;
    await _begin({
      'kind': 'submit',
      'startKey': requestKey(),
      'key': requestKey(),
      'attempt': attempt?.id,
      'revision': revision,
      'answer': answer.toJson(),
      'instance': session!.instanceId,
    });
  }

  Future<void> hint(String id) async {
    if (session == null || result != null) return;
    await _begin({
      'kind': 'hint',
      'startKey': requestKey(),
      'key': requestKey(),
      'attempt': attempt?.id,
      'revision': revision,
      'hint': id,
      'instance': session!.instanceId,
    });
  }

  Future<void> _execute() async {
    final op = _operation!;
    AttemptResult? confirmedResult;
    if (op['kind'] == 'enroll') {
      await service.enroll(
        op['journey'] as String,
        op['timezone'] as String,
        op['enrollKey'] as String,
      );
      op['kind'] = 'start';
      await _persist();
    }
    if (op['kind'] == 'start') {
      _accept(
        await service.startSession(
          op['journey'] as String,
          op['lesson'] as String,
          op['key'] as String,
        ),
      );
    } else {
      if (op['attempt'] == null) {
        // Snapshot is the revision originally sent, including on a lost response.
        final started = await service.startAttempt(
          session!,
          op['startKey'] as String,
        );
        attempt = started.attempt;
        revision = started.revision;
        op['attempt'] = attempt!.id;
        op['revision'] = revision;
        await _persist();
      }
      if (op['kind'] == 'submit') {
        confirmedResult = await service.submit(
          sessionId: session!.id,
          attemptId: op['attempt'] as String,
          instanceId: op['instance'] as String,
          revision: op['revision'] as int,
          idempotencyKey: op['key'] as String,
          answer: _answer(object(op['answer'])),
        );
        revision = confirmedResult.sessionRevision;
      } else {
        final response = await service.hint(
          session!.id,
          op['attempt'] as String,
          op['revision'] as int,
          op['hint'] as String,
          op['key'] as String,
        );
        revision = response.revision;
        hintText = response.text;
      }
    }
    // Keep intent until a fresh server read confirms the authoritative state.
    // Feedback stays visible for this screen; the saved snapshot is fresh for restart.
    final latest = op['kind'] == 'hint'
        ? LearningSession.fromJson({
            ...session!.snapshot,
            'revision': revision,
            'current_attempt': {
              'attempt_id': op['attempt'],
              'status': 'open',
              'assistance': {
                'hint_ids': {
                  ...?attempt?.hintIds,
                  op['hint'] as String,
                }.toList(),
                'revealed': attempt?.revealed ?? false,
              },
            },
          })
        : await service.session(session!.id);
    _operation = null;
    final savedHint = hintText;
    _accept(latest);
    try {
      await _persist();
      result = confirmedResult;
      hintText = savedHint;
    } catch (_) {
      _operation = op;
      rethrow;
    }
  }

  Answer _answer(Json value) => switch (value['type']) {
    'single_choice' => ChoiceAnswer(value['option_id'] as String),
    'command_order' => OrderingAnswer(strings(value['step_ids'])),
    'command_entry' => CommandAnswer(value['command'] as String),
    _ => throw const FormatException('Unsupported saved answer'),
  };
}

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/models.dart';
import '../core/services.dart';

String requestKey() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// In-memory request reconciliation. Account-bound durable recovery is app #3.
/// Retain the exact closure/payload/key on ambiguous failures; never re-grade locally.
class LearningController extends ChangeNotifier {
  LearningController(this.service);
  final LearningService service;
  LearningSession? session;
  OpenAttempt? attempt;
  AttemptResult? result;
  int revision = 0;
  bool busy = false;
  Object? error;
  String? hintText;
  Future<void> Function()? _pending;
  bool _disposed = false;
  bool get complete =>
      result?.nextAction == 'session_complete' ||
      session?.status == 'completed';
  bool get canRetry =>
      error is ServiceFailure && (error! as ServiceFailure).retryable;
  bool get hasPending => _pending != null;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    _pending = action;
    _changed();
    try {
      await action();
      _pending = null;
    } catch (failure) {
      error = failure;
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> retry() async {
    final pending = _pending;
    if (pending != null && canRetry) await _run(pending);
  }

  Future<void> start(String journey, String lesson) async {
    final key = requestKey();
    await _run(() async {
      _accept(await service.startSession(journey, lesson, key));
    });
  }

  void _accept(LearningSession value) {
    session = value;
    revision = value.revision;
    attempt = value.attempt;
    result = null;
    hintText = null;
  }

  Future<void> refresh() async {
    final id = session?.id;
    if (id == null || busy) return;
    await _run(() async {
      _accept(await service.session(id));
    });
  }

  Future<void> _ensureAttempt(String key) async {
    if (attempt != null) return;
    final started = await service.startAttempt(session!, key);
    attempt = started.attempt;
    revision = started.revision;
  }

  Future<void> submit(Answer answer) async {
    if (busy || hasPending || session?.instanceId == null || result != null) {
      return;
    }
    final startKey = requestKey(), submitKey = requestKey();
    final current = session!;
    int? submittedRevision;
    await _run(() async {
      await _ensureAttempt(startKey);
      submittedRevision ??= revision;
      result = await service.submit(
        sessionId: current.id,
        attemptId: attempt!.id,
        instanceId: current.instanceId!,
        revision: submittedRevision!,
        idempotencyKey: submitKey,
        answer: answer,
      );
      revision = result!.sessionRevision;
    });
  }

  Future<void> hint(String id) async {
    if (busy || hasPending || result != null) return;
    final startKey = requestKey(), hintKey = requestKey();
    int? hintRevision;
    await _run(() async {
      await _ensureAttempt(startKey);
      hintRevision ??= revision;
      final response = await service.hint(
        session!.id,
        attempt!.id,
        hintRevision!,
        id,
        hintKey,
      );
      revision = response.revision;
      hintText = response.text;
    });
  }
}

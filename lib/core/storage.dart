import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class CredentialStore {
  Future<String?> readAccessToken();
  Future<void> writeAccessToken(String token);
  Future<void> clear();
}

class SecureCredentialStore implements CredentialStore {
  const SecureCredentialStore([
    this.storage = const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  ]);
  final FlutterSecureStorage storage;
  static const _key = 'syskata.access_token';
  @override
  Future<String?> readAccessToken() => storage.read(key: _key);
  @override
  Future<void> writeAccessToken(String token) =>
      storage.write(key: _key, value: token);
  @override
  Future<void> clear() => storage.delete(key: _key);
}

/// Payload and key share one row/transaction. Callers must reconcile before send.
/// Authentication lifecycle and replay orchestration are implemented in app #3.
class RecoveryRecord {
  const RecoveryRecord({
    required this.accountId,
    required this.sessionId,
    required this.bundleVersion,
    required this.instanceId,
    required this.idempotencyKey,
    required this.payload,
  });
  final String accountId,
      sessionId,
      bundleVersion,
      instanceId,
      idempotencyKey,
      payload;
  Map<String, Object?> toRow() => {
    'account_id': accountId,
    'session_id': sessionId,
    'bundle_version': bundleVersion,
    'instance_id': instanceId,
    'idempotency_key': idempotencyKey,
    'payload': payload,
  };
  factory RecoveryRecord.fromRow(Map<String, Object?> row) => RecoveryRecord(
    accountId: row['account_id']! as String,
    sessionId: row['session_id']! as String,
    bundleVersion: row['bundle_version']! as String,
    instanceId: row['instance_id']! as String,
    idempotencyKey: row['idempotency_key']! as String,
    payload: row['payload']! as String,
  );
}

class RecoveryStore implements RecoveryJournal {
  RecoveryStore(this.database);
  final Database database;
  static Future<RecoveryStore> open() async {
    var path = 'syskata-recovery.db';
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final directory = await const MethodChannel('org.syskata.app/recovery')
          .invokeMethod<String>('directory');
      if (directory == null) throw StateError('Recovery directory unavailable');
      path = '$directory/syskata-recovery.db';
    }
    return RecoveryStore(
      await openDatabase(
        path,
        version: 2,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createJournal(db);
        },
        onCreate: (db, version) async {
          await _createJournal(db);
          await db.execute(
            'CREATE TABLE pending (account_id TEXT NOT NULL, '
            'session_id TEXT NOT NULL, bundle_version TEXT NOT NULL, instance_id TEXT NOT NULL, '
            'idempotency_key TEXT NOT NULL, payload TEXT NOT NULL, '
            'PRIMARY KEY (account_id, session_id))',
          );
        },
      ),
    );
  }

  Future<void> save(RecoveryRecord record) => database.transaction((txn) async {
    await txn.insert(
      'pending',
      record.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  });
  Future<RecoveryRecord?> read(String accountId, String sessionId) async {
    final rows = await database.query(
      'pending',
      where: 'account_id = ? AND session_id = ?',
      whereArgs: [accountId, sessionId],
    );
    return rows.isEmpty ? null : RecoveryRecord.fromRow(rows.single);
  }

  static Future<void> _createJournal(Database db) => db.execute(
    'CREATE TABLE journal (account_id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
  );
  @override
  Future<Map<String, dynamic>?> load(String accountId) async {
    final rows = await database.query(
      'journal',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
    return rows.isEmpty
        ? null
        : jsonDecode(rows.single['payload']! as String) as Map<String, dynamic>;
  }

  @override
  Future<void> write(String accountId, Map<String, dynamic> payload) =>
      database.transaction((txn) async {
        await txn.insert('journal', {
          'account_id': accountId,
          'payload': jsonEncode(payload),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
  @override
  Future<void> clearAccount(String accountId) async {
    await database.delete(
      'journal',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
    await database.delete(
      'pending',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
  }

  Future<void> close() => database.close();
}

abstract interface class RecoveryJournal {
  Future<Map<String, dynamic>?> load(String accountId);
  Future<void> write(String accountId, Map<String, dynamic> payload);
  Future<void> clearAccount(String accountId);
}

/// Reject late writes from controllers belonging to a signed-out authentication generation.
class ScopedRecoveryJournal implements RecoveryJournal {
  ScopedRecoveryJournal(this.delegate, this.isCurrent);
  final RecoveryJournal delegate;
  final bool Function() isCurrent;
  void _check() {
    if (!isCurrent()) throw StateError('Account session ended');
  }

  @override
  Future<Map<String, dynamic>?> load(String accountId) {
    _check();
    return delegate.load(accountId);
  }

  @override
  Future<void> write(String accountId, Map<String, dynamic> payload) {
    _check();
    return delegate.write(accountId, payload);
  }

  @override
  Future<void> clearAccount(String accountId) {
    _check();
    return delegate.clearAccount(accountId);
  }
}

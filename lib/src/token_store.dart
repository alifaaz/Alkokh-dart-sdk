import 'dart:convert';

import 'models.dart';

abstract interface class TokenStore {
  Future<AuthSession?> read();

  Future<void> write(AuthSession session);

  Future<void> clear();
}

class MemoryTokenStore implements TokenStore {
  AuthSession? _session;

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> write(AuthSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}

typedef TokenValueReader = Future<String?> Function(String key);
typedef TokenValueWriter = Future<void> Function(String key, String value);
typedef TokenValueDeleter = Future<void> Function(String key);

class KeyValueTokenStore implements TokenStore {
  KeyValueTokenStore({
    required TokenValueReader readValue,
    required TokenValueWriter writeValue,
    required TokenValueDeleter deleteValue,
    this.key = 'alkokh_mobile_session',
  }) : _readValue = readValue,
       _writeValue = writeValue,
       _deleteValue = deleteValue;

  final String key;
  final TokenValueReader _readValue;
  final TokenValueWriter _writeValue;
  final TokenValueDeleter _deleteValue;

  @override
  Future<AuthSession?> read() async {
    final raw = await _readValue(key);
    if (raw == null || raw.isEmpty) return null;
    return AuthSession.fromStoredJson(jsonDecode(raw) as Map<String, Object?>);
  }

  @override
  Future<void> write(AuthSession session) {
    return _writeValue(key, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() {
    return _deleteValue(key);
  }
}

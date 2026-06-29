import 'dart:convert';

class CacheEntry {
  const CacheEntry({required this.data, required this.createdAt});

  final Map<String, Object?> data;
  final DateTime createdAt;

  bool isFresh(Duration ttl, DateTime now) {
    return now.difference(createdAt) < ttl;
  }

  Map<String, Object?> toJson() {
    return {'data': data, 'created_at': createdAt.toIso8601String()};
  }

  static CacheEntry fromJson(Map<String, Object?> json) {
    return CacheEntry(
      data: _stringMap(json['data']),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

abstract interface class CacheStore {
  Future<CacheEntry?> read(String key);

  Future<void> write(String key, CacheEntry entry);

  Future<void> delete(String key);

  Future<void> deleteWhere(bool Function(String key) test);

  Future<void> clear();
}

class MemoryCacheStore implements CacheStore {
  final Map<String, CacheEntry> _entries = {};

  @override
  Future<CacheEntry?> read(String key) async => _entries[key];

  @override
  Future<void> write(String key, CacheEntry entry) async {
    _entries[key] = entry;
  }

  @override
  Future<void> delete(String key) async {
    _entries.remove(key);
  }

  @override
  Future<void> deleteWhere(bool Function(String key) test) async {
    _entries.removeWhere((key, _) => test(key));
  }

  @override
  Future<void> clear() async {
    _entries.clear();
  }
}

typedef CacheValueReader = Future<String?> Function(String key);
typedef CacheValueWriter = Future<void> Function(String key, String value);
typedef CacheValueDeleter = Future<void> Function(String key);

class KeyValueCacheStore implements CacheStore {
  KeyValueCacheStore({
    required CacheValueReader readValue,
    required CacheValueWriter writeValue,
    required CacheValueDeleter deleteValue,
    this.keyPrefix = 'alkokh_mobile_cache',
  }) : _readValue = readValue,
       _writeValue = writeValue,
       _deleteValue = deleteValue;

  final String keyPrefix;
  final CacheValueReader _readValue;
  final CacheValueWriter _writeValue;
  final CacheValueDeleter _deleteValue;

  String get _indexKey => '$keyPrefix:index';

  String _storageKey(String key) => '$keyPrefix:$key';

  @override
  Future<CacheEntry?> read(String key) async {
    final raw = await _readValue(_storageKey(key));
    if (raw == null || raw.isEmpty) return null;
    return CacheEntry.fromJson(jsonDecode(raw) as Map<String, Object?>);
  }

  @override
  Future<void> write(String key, CacheEntry entry) async {
    await _writeValue(_storageKey(key), jsonEncode(entry.toJson()));
    final keys = await _readIndex();
    if (keys.add(key)) {
      await _writeIndex(keys);
    }
  }

  @override
  Future<void> delete(String key) async {
    await _deleteValue(_storageKey(key));
    final keys = await _readIndex();
    if (keys.remove(key)) {
      await _writeIndex(keys);
    }
  }

  @override
  Future<void> deleteWhere(bool Function(String key) test) async {
    final keys = await _readIndex();
    final keep = <String>{};
    for (final key in keys) {
      if (test(key)) {
        await _deleteValue(_storageKey(key));
      } else {
        keep.add(key);
      }
    }
    await _writeIndex(keep);
  }

  @override
  Future<void> clear() async {
    final keys = await _readIndex();
    for (final key in keys) {
      await _deleteValue(_storageKey(key));
    }
    await _deleteValue(_indexKey);
  }

  Future<Set<String>> _readIndex() async {
    final raw = await _readValue(_indexKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Object?;
    if (decoded is! List) return {};
    return decoded.map((value) => value.toString()).toSet();
  }

  Future<void> _writeIndex(Set<String> keys) {
    return _writeValue(_indexKey, jsonEncode(keys.toList()..sort()));
  }
}

Map<String, Object?> _stringMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return {};
}

import 'dart:convert';
import '../utils/storage_service.dart';

class _CacheEntry {
  final String response;
  final DateTime cachedAt;

  _CacheEntry(this.response, this.cachedAt);

  bool isExpired(Duration ttl) =>
      DateTime.now().difference(cachedAt) > ttl;

  Map<String, dynamic> toJson() => {
        'response': response,
        'cachedAt': cachedAt.toIso8601String(),
      };

  static _CacheEntry? fromJson(Map<String, dynamic> json) {
    try {
      return _CacheEntry(
        json['response'] as String,
        DateTime.parse(json['cachedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

class AiResponseCache {
  static const String _key = 'ai_response_cache_v1';
  static const Duration _defaultTTL = Duration(minutes: 30);
  static const int _maxEntries = 50;

  static String _hash(String input) =>
      base64Encode(utf8.encode(input)).substring(0, 32);

  static Map<String, dynamic> _read() {
    final raw = StorageService.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static void _write(Map<String, dynamic> data) {
    StorageService.setString(_key, jsonEncode(data));
  }

  static String? get(String query, {Duration? ttl}) {
    final hash = _hash(query);
    final data = _read();
    final entryData = data[hash];
    if (entryData == null) return null;
    final entry = _CacheEntry.fromJson(entryData as Map<String, dynamic>);
    if (entry == null) return null;
    if (entry.isExpired(ttl ?? _defaultTTL)) {
      _remove(hash);
      return null;
    }
    return entry.response;
  }

  static void put(String query, String response) {
    final hash = _hash(query);
    final data = _read();
    data[hash] = _CacheEntry(response, DateTime.now()).toJson();
    if (data.length > _maxEntries) {
      final keys = data.keys.toList();
      final oldest = keys.first;
      data.remove(oldest);
    }
    _write(data);
  }

  static void _remove(String hash) {
    final data = _read();
    data.remove(hash);
    _write(data);
  }

  static void clear() => StorageService.removeString(_key);

  static void invalidateOnDataChange() => clear();
}

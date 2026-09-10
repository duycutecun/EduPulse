import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'ai_models.dart';
import '../utils/storage_service.dart';

/// Tự động cập nhật danh sách model miễn phí của OpenRouter.
///
/// - Gọi `GET https://openrouter.ai/api/v1/models` một lần mỗi 24h.
/// - Lọc các model giá 0đ (hậu tố `:free` hoặc pricing 0) và cache kết quả
///   vào SharedPreferences để lần mở app sau không cần gọi lại mạng.
/// - Luôn giữ `openrouter/free` (Auto) và Gemini (Key) trong danh sách runtime
///   để người dùng luôn có phương án dự phòng kể cả khi offline / API đổi cấu
///   trúc.
class FreeModelsCatalog {
  FreeModelsCatalog._();

  static const String _endpoint = 'https://openrouter.ai/api/v1/models';

  /// Kết quả fetch mới nhất (null nếu chưa fetch lần nào).
  static ValueNotifier<List<AIModel>?> runtimeModels =
      ValueNotifier<List<AIModel>?>(null);

  static bool _loading = false;
  static final _completers = <Completer<void>>[];

  /// Đảm bảo catalog đã được tải (từ cache hoặc mạng). Không ném lỗi.
  static Future<void> ensureLoaded() {
    if (runtimeModels.value != null) return Future.value();
    if (_loading) {
      final c = Completer<void>();
      _completers.add(c);
      return c.future;
    }
    // Có cache còn hạn → dùng ngay, không cần mạng.
    if (_loadCache()) return Future.value();
    return refresh();
  }

  /// Gọi OpenRouter lấy danh sách model miễn phí và cập nhật runtimeModels.
  /// Chỉ chạy lại nếu cache đã quá 24h. Không ném lỗi.
  static Future<void> refresh({bool force = false}) async {
    if (_loading) return;
    if (!force && _loadCache()) return;
    _loading = true;
    try {
      final resp = await http
          .get(Uri.parse(_endpoint))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return;
      final data = jsonDecode(resp.body)['data'] as List? ?? [];
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final free = <AIModel>[];
      for (final m in data) {
        final id = m['id'] as String? ?? '';
        if (id.isEmpty) continue;
        // Auto (openrouter/free) luôn được thêm riêng ở trên — tránh trùng lặp.
        if (id == AIModel.defaultModel.slug) continue;
        final pricing = m['pricing'] as Map<String, dynamic>? ?? const {};
        final isFree =
            id.endsWith(':free') || (pricing['prompt'] == '0' && pricing['completion'] == '0');
        if (!isFree) continue;
        // Bỏ model không xuất text thuần (vd: sinh audio như Lyria).
        final modality = m['architecture']?['modality'] as String? ?? '';
        if (modality.isNotEmpty && !modality.contains('->text')) continue;
        final modalityIn = m['architecture']?['input_modalities'] as List? ?? const [];
        final name = (m['name'] as String? ?? id)
            .replaceAll(RegExp(r'\s*\(free\)\s*$', caseSensitive: false), '')
            .trim();
        // Bỏ prefix vendor trong tên hiển thị: "NVIDIA: Nemotron 3 Ultra" → "Nemotron 3 Ultra".
        final display = name.contains(': ') ? name.split(': ').last : name;
        free.add(AIModel(
          slug: id,
          label: display,
          description: _describe(id, modalityIn),
          supportsVision: modalityIn.contains('image'),
        ));
      }
      // Sắp xếp: model mới nhất lên đầu (trừ Auto luôn đứng đầu).
      free.sort((a, b) => _createdOrder(a.slug, b.slug, data));
      final result = <AIModel>[AIModel.defaultModel, ...free];
      // Giữ các model chạy bằng key riêng của chủ app (slug 'gemini/...') —
      // chúng không nằm trong danh sách free của OpenRouter nhưng luôn dùng được.
      for (final m in AIModel.definitions) {
        if (m.slug.startsWith('gemini/') &&
            !result.any((r) => r.slug == m.slug)) {
          result.add(m);
        }
      }
      runtimeModels.value = result;
      _saveCache(result, now);
    } catch (_) {
      // Offline / lỗi mạng → dùng cache cũ (kể cả quá hạn) nếu có;
      // nếu không có gì thì giữ nguyên danh sách tĩnh.
      if (runtimeModels.value == null) _loadCache(allowStale: true);
    } finally {
      _loading = false;
      for (final c in _completers) {
        if (!c.isCompleted) c.complete();
      }
      _completers.clear();
    }
  }

  /// Đọc cache từ SharedPreferences; trả false nếu hết hạn (>24h) hoặc lỗi.
  /// [allowStale] dùng cache quá hạn làm phương án dự phòng khi offline.
  static bool _loadCache({bool allowStale = false}) {
    if (runtimeModels.value != null) return true;
    final raw = StorageService.getFreeModelsCache();
    final ts = StorageService.getFreeModelsCacheTime();
    if (raw == null || raw.isEmpty || ts == null) return false;
    final fetchedAt = int.tryParse(ts) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch ~/ 1000 - fetchedAt;
    if (!allowStale && age > const Duration(hours: 24).inSeconds) return false;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => AIModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isEmpty) return false;
      runtimeModels.value = list;
      return true;
    } catch (_) {
      return false;
    }
  }

  static void _saveCache(List<AIModel> models, int fetchedAtSec) {
    try {
      StorageService.setFreeModelsCache(
          jsonEncode(models.map((m) => m.toJson()).toList()));
      StorageService.setFreeModelsCacheTime(fetchedAtSec.toString());
    } catch (_) {}
  }

  /// So sánh thứ tự theo thời điểm tạo model (mới lên trước); Auto đứng đầu.
  static int _createdOrder(String a, String b, List<dynamic> data) {
    int createdOf(String slug) {
      for (final m in data) {
        if (m['id'] == slug) return (m['created'] as num?)?.toInt() ?? 0;
      }
      return 0;
    }

    final ca = createdOf(a);
    final cb = createdOf(b);
    return cb.compareTo(ca);
  }

  /// Mô tả ngắn cho model runtime (đơn giản hơn bản tĩnh).
  static String _describe(String slug, List<dynamic> inputModalities) {
    final feats = <String>[];
    if (inputModalities.contains('image')) feats.add('đọc ảnh');
    if (inputModalities.contains('audio')) feats.add('nghe audio');
    if (inputModalities.contains('video')) feats.add('đọc video');
    final ctx = 'miễn phí';
    return feats.isEmpty ? ctx : '$ctx · ${feats.join(', ')}';
  }
}

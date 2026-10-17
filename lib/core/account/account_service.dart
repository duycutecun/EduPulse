import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../utils/auth_service.dart';

/// Một loại dữ liệu có thời hạn lưu trữ (trả từ `GET /api/account`).
class RetentionItem {
  const RetentionItem({
    required this.key,
    required this.label,
    required this.ttlDays,
  });

  final String key;
  final String label;

  /// Số ngày lưu tối đa; `null` = giữ tới khi người dùng xoá.
  final int? ttlDays;

  factory RetentionItem.fromJson(Map<String, dynamic> json) => RetentionItem(
        key: (json['key'] ?? '').toString(),
        label: (json['label'] ?? '').toString(),
        ttlDays: (json['ttlDays'] as num?)?.toInt(),
      );
}

/// Kết quả xoá dữ liệu cá nhân: số dòng đã xoá theo bảng.
class DeleteDataResult {
  const DeleteDataResult({required this.ok, this.deleted, this.message});

  final bool ok;
  final Map<String, int>? deleted;
  final String? message;

  int get totalDeleted =>
      deleted?.values.fold<int>(0, (sum, n) => sum + n) ?? 0;
}

/// Cầu nối tới `/api/account` — chính sách lưu trữ + xoá dữ liệu cá nhân
/// (đặc tả mục 8, dòng 214). Server xác thực Supabase access token; client không
/// bao giờ gọi thẳng Supabase.
class AccountService {
  AccountService._();

  static Uri _endpoint() => AppConfig.apiBase().resolve('/api/account');

  /// Chính sách lưu trữ (công khai). Trả danh sách rỗng nếu mất mạng.
  static Future<List<RetentionItem>> fetchRetention() async {
    try {
      final resp =
          await http.get(_endpoint()).timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) return const [];
      final list = decoded['retention'];
      if (list is! List) return const [];
      return [
        for (final e in list)
          if (e is Map) RetentionItem.fromJson(Map<String, dynamic>.from(e)),
      ];
    } catch (e) {
      debugPrint('[AccountService] Lỗi tải chính sách lưu trữ: $e');
      return const [];
    }
  }

  /// Xoá dữ liệu cá nhân đã lưu trên máy chủ của chính người đang đăng nhập.
  ///
  /// Cần đăng nhập; trả `ok:false` kèm thông báo nếu chưa đăng nhập/mất mạng.
  static Future<DeleteDataResult> deleteMyData() async {
    // access token Supabase (ngắn hạn, tự refresh) — server tự xác thực JWT.
    final token = await AuthService.idToken();
    if (token == null || token.isEmpty) {
      return const DeleteDataResult(
        ok: false,
        message: 'Bạn cần đăng nhập để xoá dữ liệu trên máy chủ.',
      );
    }

    try {
      final resp = await http
          .post(
            _endpoint(),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'idToken': token,
              'action': 'delete_my_data',
              'confirm': true,
            }),
          )
          .timeout(const Duration(seconds: 30));
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) {
        return const DeleteDataResult(
          ok: false,
          message: 'Máy chủ trả về dữ liệu không hợp lệ.',
        );
      }
      final map = Map<String, dynamic>.from(decoded);
      if (map['ok'] != true) {
        return DeleteDataResult(
          ok: false,
          message: (map['error'] ?? 'Xoá dữ liệu không thành công.').toString(),
        );
      }
      final raw = map['deleted'];
      final deleted = <String, int>{};
      if (raw is Map) {
        raw.forEach((k, v) {
          if (v is num) deleted[k.toString()] = v.toInt();
        });
      }
      return DeleteDataResult(ok: true, deleted: deleted);
    } catch (e) {
      debugPrint('[AccountService] Lỗi xoá dữ liệu: $e');
      return const DeleteDataResult(
        ok: false,
        message: 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.',
      );
    }
  }
}

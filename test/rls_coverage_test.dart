import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Gate M1' ④ — "0 sync fail **với RLS bật**" + mục 2b của
/// `docs/CHECKLIST_PHAT_HANH.md`.
///
/// Việc **áp** migration lên Supabase vẫn là thao tác tay (cần khoá
/// `service_role`, không chạy được trong CI), nhưng thứ kiểm được ngay trong
/// repo là: mọi bảng mà API đọc/ghi, và mọi bảng do repo tạo ra, đều phải có
/// `enable row level security` ở một tệp `supabase/*.sql`.
///
/// Vì sao đây là gate thật chứ không phải thủ tục: khoá `anon` nằm trong bản
/// build web/app công khai. Một bảng quên bật RLS nghĩa là bất kỳ ai cũng đọc
/// được chat phụ huynh↔con hoặc mã OTP qua PostgREST — và không có triệu chứng
/// nào ở phía client để ai đó phát hiện ra. Test này đỏ ngay khi có bảng mới
/// (hoặc endpoint mới) mà thiếu RLS.
void main() {
  final apiDir = Directory('api');
  final supabaseDir = Directory('supabase');

  /// Bảng mà lớp API thực sự truy cập.
  Set<String> apiTables() {
    final tables = <String>{};
    final consts = <String, String>{};

    final files = apiDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.js') && !f.path.endsWith('.test.js'));

    for (final file in files) {
      final src = file.readAsStringSync();
      // Hằng số tên bảng (`const GOAL_TABLE = 'family_goals'`) — API gọi
      // `.from(GOAL_TABLE)`, nên nếu không giải hằng số thì test sẽ "xanh" một
      // cách vô nghĩa vì không tìm thấy bảng nào.
      for (final match in RegExp(r"const\s+([A-Z][A-Z0-9_]*)\s*=\s*'([a-z_]+)'")
          .allMatches(src)) {
        consts[match.group(1)!] = match.group(2)!;
        if (match.group(1)!.endsWith('_TABLE')) {
          tables.add(match.group(2)!);
        }
      }
      for (final match
          in RegExp(r"\.from\(\s*'([a-z_]+)'\s*\)").allMatches(src)) {
        tables.add(match.group(1)!);
      }
      for (final match
          in RegExp(r"\.from\(\s*([A-Z][A-Z0-9_]*)\s*[,)]").allMatches(src)) {
        final resolved = consts[match.group(1)!];
        if (resolved != null) tables.add(resolved);
      }
    }
    return tables;
  }

  /// Bảng do repo tạo ra (mọi tệp SQL trong `supabase/`).
  Set<String> createdTables() {
    final tables = <String>{};
    for (final file in supabaseDir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.sql')) continue;
      final src = file.readAsStringSync();
      for (final match in RegExp(
              r'create\s+table\s+(?:if\s+not\s+exists\s+)?public\.([a-z_]+)',
              caseSensitive: false)
          .allMatches(src)) {
        tables.add(match.group(1)!);
      }
    }
    return tables;
  }

  /// Bảng đã bật Row Level Security ở một tệp SQL nào đó.
  Set<String> rlsTables() {
    final tables = <String>{};
    for (final file in supabaseDir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.sql')) continue;
      final src = file.readAsStringSync();
      for (final match in RegExp(
              r'alter\s+table\s+(?:if\s+exists\s+)?public\.([a-z_]+)\s+enable\s+row\s+level\s+security',
              caseSensitive: false)
          .allMatches(src)) {
        tables.add(match.group(1)!);
      }
    }
    return tables;
  }

  test('mọi bảng API truy cập đều đã bật RLS', () {
    final used = apiTables();
    final secured = rlsTables();

    // Chốt chống "xanh giả": nếu bộ phân tích hỏng thì đây là thứ báo trước.
    expect(used.length, greaterThanOrEqualTo(5),
        reason: 'không tìm thấy bảng nào trong api/ — bộ tìm kiếm đã hỏng, '
            'kết quả xanh ở dưới vô nghĩa');
    expect(secured.length, greaterThanOrEqualTo(8),
        reason: 'không tìm thấy lệnh bật RLS nào trong supabase/');

    final missing = used.difference(secured).toList()..sort();
    expect(missing, isEmpty,
        reason: 'bảng API đọc/ghi nhưng chưa bật RLS: $missing — '
            'khoá anon công khai nằm trong bản build, thiếu RLS là lộ dữ liệu');
  });

  test('mọi bảng do repo tạo ra đều đã bật RLS', () {
    final created = createdTables();
    final secured = rlsTables();

    final missing = created.difference(secured).toList()..sort();
    expect(missing, isEmpty,
        reason: 'bảng tạo trong supabase/*.sql nhưng thiếu '
            '`enable row level security`: $missing');
  });

  test('hai migration đang chờ áp lên Supabase có mặt và bật RLS đủ', () {
    // Mục 2b của checklist phát hành: hai tệp này phải được áp **trước** khi mở
    // beta công khai. Test không áp được (cần service_role), nhưng giữ cho tệp
    // không bị xoá/đổi tên câm lặng.
    final familyV4 = File('supabase/family_v4.sql');
    final emailCodes = File('supabase/email_codes.sql');
    expect(familyV4.existsSync(), isTrue);
    expect(emailCodes.existsSync(), isTrue);

    final secured = rlsTables();
    for (final table in const [
      'family_goals',
      'family_messages',
      'family_notif_tokens',
      'email_codes',
    ]) {
      expect(secured, contains(table),
          reason: '$table phải được bật RLS trong một tệp supabase/*.sql');
    }
  });
}

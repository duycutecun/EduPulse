import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Gate M3 ① — "Bỏ thi đua; **0 màn hiện người khác**"
/// (`docs/BAN_THAY_DOI_V2.md`, mục C.1 và Gate phát hành).
///
/// Vì sao là gate thật chứ không phải "rà tay": màn thi đua cộng đồng từng
/// tồn tại trong repo (`leaderboard_view.dart` + `fetchLeaderboard` + bảng
/// `leaderboard`) và mã chết đó đi lạc trở lại chỉ cần một lệnh revert —
/// không có triệu chứng nào ở màn hình mới lại báo đỏ. Test này quét toàn bộ
/// `lib/` và đỏ ngay khi mã hiển thị số/tên người khác được dính lại đầu,
/// kể cả chỉ là mã chưa được dùng.
///
/// Kỷ lục cá nhân ("Bảng vàng kỷ lục" — chỉ số của chính user) được đặc tả
/// giữ lại, cùng tồn tại dưới tên `LeaderboardScreen` vì tính năng chỉ là
/// kỷ lục cá nhân; test cũng kiểm nó **chỉ** hiện kỷ lục cá nhân.
void main() {
  /// Định danh của mã thi đua cộng đồng đã bị gỡ — không được quay lại.
  const banned = <String>[
    'CommunityUser',
    'fetchLeaderboard',
    'leaderboard_view',
  ];

  /// Tên màn/bảng xếp hạng cờ vua cộng đồng — chỉ dính khi có màn hiện
  /// số/tên người khác.
  const bannedUis = <String>['bảng xếp hạng', 'xếp hạng toàn cầu'];

  test('lib/ không còn mã thi đua cộng đồng đã gỡ (0 màn hiện người khác)', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Comment giải thích lịch sử/quyết định được phép nhắc tên tính năng
        // cũ — chỉ mã render là cấm.
        final isComment = line.trimLeft().startsWith('///');
        for (final b in banned) {
          if (line.contains(b)) offenders.add('${entity.path}:${i + 1}: "$b"');
        }
        if (isComment) continue;
        for (final b in bannedUis) {
          if (line.toLowerCase().contains(b)) {
            offenders.add('${entity.path}:${i + 1}: "$b"');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Mã hiện người khác quay lại ở:\n${offenders.join('\n')}');
  });

  test('Kỷ lục cá nhân được giữ — màn chỉ nói về số của chính user', () {
    final file = File(
        'lib/features/leaderboard/presentation/screens/leaderboard_screen.dart');
    expect(file.existsSync(), isTrue,
        reason: '"Bảng vàng kỷ lục" là nội dung được đặc tả giữ lại (M3 C.1)');
    final src = file.readAsStringSync().toLowerCase();
    expect(src.contains('kỷ lục'), isTrue,
        reason:
            'Màn phải là bảng kỷ lục cá nhân, không phải thi đua cộng đồng');
  });
}

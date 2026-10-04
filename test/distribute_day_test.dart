import 'package:flutter_test/flutter_test.dart';

import 'package:edupulse/features/study/domain/distribute_day.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';

/// Test tính năng "Phân bố task hợp lý theo ngày".
void main() {
  final now = DateTime(2026, 10, 1, 15);

  TodayTask task(
    String id,
    String subject,
    int minutes, {
    String priority = 'medium',
    DateTime? deadline,
    DateTime? scheduledAt,
    String status = 'todo',
  }) =>
      TodayTask(
        id: id,
        title: 'Học $subject ($minutes phút)',
        subject: subject,
        priority: priority,
        status: status,
        estimateMinutes: minutes,
        deadline: deadline,
        scheduledAt: scheduledAt,
      );

  test('Hôm nay nhẹ hơn quỹ → không đề xuất gì (không quấy rầy)', () {
    final proposals = proposeDayBalance(tasks: [
      task('a', 'Toán', 45),
      task('b', 'Lý', 45),
    ], now: now);
    expect(proposals, isEmpty);
  });

  test('Đúng quỹ 120 phút → không đề xuất', () {
    final proposals = proposeDayBalance(tasks: [
      task('a', 'Toán', 60),
      task('b', 'Lý', 60),
    ], now: now);
    expect(proposals, isEmpty);
  });

  test('Quá quỹ → dời task mức thấp trước, từng phần đến khi vừa quỹ', () {
    final proposals = proposeDayBalance(tasks: [
      task('low', 'Sử', 30, priority: 'low'),
      task('medium', 'Lý', 45),
      task('high', 'Toán', 60, priority: 'high'),
    ], now: now);

    // Tổng 135 phút > 120 → cần dời ≥ 15 phút. Task low (30') được chọn
    // trước và dời nguyên khối — sau khi dời còn 105 ≤ 120 → dừng.
    expect(proposals, hasLength(1));
    expect(proposals.first.task.id, 'low');
    // Ngày nhận: ngày mai 19:00.
    expect(proposals.first.proposedStart.day, 2);
    expect(proposals.first.proposedStart.hour, 19);
  });

  test('KHÔNG BAO GIỜ dời task có deadline hôm nay hoặc đã quá hạn', () {
    final proposals = proposeDayBalance(tasks: [
      task('urgent', 'Toán', 90,
          priority: 'low', deadline: DateTime(2026, 10, 1, 23)),
      task('overdue', 'Hóa', 60,
          priority: 'low', deadline: DateTime(2026, 9, 28)),
    ], now: now);
    expect(proposals, isEmpty); // cả 2 đều bất động → không đủ ứng viên.
  });

  test('Task đã xong/bỏ qua không bị dời', () {
    final proposals = proposeDayBalance(tasks: [
      task('done', 'Sử', 90, status: 'completed'),
      task('skip', 'Địa', 60, status: 'skipped'),
    ], now: now);
    expect(proposals, isEmpty);
  });

  test('Dời nhiều task khi quá tải lớn, ngày nhận không vượt quỹ', () {
    final proposals = proposeDayBalance(tasks: [
      task('m1', 'Sử', 60, priority: 'low'),
      task('m2', 'Địa', 60, priority: 'low'),
      task('m3', 'GDCD', 60, priority: 'low'),
      task('core', 'Toán', 90, priority: 'high'),
    ], now: now);

    // Tổng 270 phút. Cần dời ≥ 150 phút → tối thiểu 3 task 60' (180').
    expect(proposals.length, greaterThanOrEqualTo(3));
    // Toán (high, cần giữ) không bao giờ nằm trong đề xuất khi còn ứng viên low.
    expect(proposals.any((p) => p.task.id == 'core'), isFalse);
    // Mỗi ngày nhận không bị nhồi quá quỹ: 3 task 60' → 2 ngày khác nhau
    // (mỗi ngày tối đa 120').
    final days = proposals.map((p) => p.proposedStart.day).toSet();
    expect(days.length, lessThanOrEqualTo(2));
  });

  test(
      'Task đã có giờ cụ thể hôm nay vẫn được xem là nằm trong kế hoạch hôm nay',
      () {
    final proposals = proposeDayBalance(tasks: [
      task('fixed', 'Toán', 100,
          priority: 'low', scheduledAt: DateTime(2026, 10, 1, 19)),
      task('b', 'Lý', 40),
    ], now: now);
    // 140 phút > 120 → đề xuất dời 'fixed' (low trước).
    expect(proposals, hasLength(1));
    expect(proposals.first.task.id, 'fixed');
  });
}

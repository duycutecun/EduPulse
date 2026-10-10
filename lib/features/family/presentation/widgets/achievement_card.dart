import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/share/share_text.dart';
import '../../domain/achievement_data.dart';

/// Tấm ảnh "thành tựu tuần" để học sinh chia sẻ ra ngoài.
///
/// Hai điều quan trọng nhất của thẻ này:
/// 1. **Nhận diện EduPulse phải rõ ngay cả khi ảnh bị crop/thumbnail**: logo
///    linh vật + chữ EduPulse ở ĐẦU, và chân ảnh luôn có tên app + mô tả
///    "trợ lý sĩ tử" + link tải. Người xem ảnh biết ngay bạn này đang dùng app
///    hỗ trợ học tập nào, chứ không chỉ thấy mấy con số.
/// 2. **Kích thước cố định** để ảnh xuất ra luôn cùng tỉ lệ (story 9:16), không
///    phụ thuộc màn hình người dùng. Mọi kích cỡ ở đây là số cứng — không dùng
///    `MediaQuery` của app.
class AchievementCard extends StatelessWidget {
  const AchievementCard({super.key, required this.data});

  final AchievementData data;

  /// Kích thước logic của ảnh (9:16).
  ///
  /// Cố ý cứng: widget này LUÔN nằm ở khổ thật, việc thu nhỏ để xem trước do
  /// `FittedBox` bọc BÊN NGOÀI `RepaintBoundary` lo. Nhờ vậy ảnh chụp ra luôn
  /// 1080×1920 dù khung xem trước nhỏ cỡ nào — nếu để thẻ tự co theo tỉ lệ xem
  /// trước thì ảnh chia sẻ sẽ nhỏ và mờ.
  static const double logicalWidth = 360;
  static const double logicalHeight = 640;

  @override
  Widget build(BuildContext context) {
    final stats = achievementStats(data);

    return SizedBox(
      width: logicalWidth,
      height: logicalHeight,
      // Ảnh phải giống nhau với mọi người dùng: bỏ hệ số phóng chữ của hệ điều
      // hành / cài đặt trong app (nếu không, người đặt cỡ chữ L sẽ xuất ra ảnh
      // tràn chữ).
      child: MediaQuery(
        data: const MediaQueryData(),
        child: _card(context, stats),
      ),
    );
  }

  Widget _card(BuildContext context, List<AchievementStat> stats) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: Stack(
        children: [
          // Hình mờ trang trí ở nền — giữ ảnh có chiều sâu mà không lấn chữ.
          Positioned(
            right: -40,
            top: 120,
            child: Opacity(
              opacity: 0.10,
              child: Image.asset(
                'assets/images/mascot.png',
                width: 240,
                height: 240,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _brandHeader(),
                const SizedBox(height: 14),
                Text(
                  data.headline,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 22,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${data.weekLabel} · ${data.studentName}',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 12),
                // Khối số liệu co giãn được: số dòng thay đổi 1–5 và tên kỳ thi
                // dài ngắn tuỳ người dùng, nên nếu nội dung cao hơn khung thì
                // THU NHỎ đều thay vì tràn ra ngoài (ảnh tràn là ảnh lỗi).
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: _statsCard(stats),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _brandFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Đầu ảnh: logo + tên app + mô tả app làm gì.
  Widget _brandHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(5),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Image.asset(
            'assets/images/mascot.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EduPulse',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 22,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Trợ lý sĩ tử & đếm ngược kỳ thi',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Khối số liệu trên nền trắng — vùng duy nhất có chữ tối để ảnh dễ đọc khi
  /// bị thu nhỏ trong newsfeed.
  Widget _statsCard(List<AchievementStat> stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SỐ LIỆU TUẦN NÀY',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          for (final stat in stats) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stat.emoji, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.label,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        stat.value,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 15,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (stat != stats.last) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }

  /// Chân ảnh: link tải + chữ ký. Luôn hiện, kể cả khi ảnh bị cắt bớt hai bên.
  Widget _brandFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              'Học cùng EduPulse',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          ShareText.appLink,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../study/domain/models/study_models.dart';
import '../../../study/domain/repositories/study_session_repository.dart';
import '../../domain/personal_records.dart';

/// "Bảng vàng kỷ lục" (P2 — mở rộng leaderboard/cộng đồng).
///
/// Thay vì bảng xếp hạng toàn cầu gửi dữ liệu học lên mạng, đây là bảng kỷ lục
/// của **chính người học**: phiên dài nhất, ngày/tuần học nhiều nhất, chuỗi
/// ngày, điểm cao nhất… Hoàn toàn offline, không gọi AI, không chia sẻ ra ngoài.
class LeaderboardScreen extends StatefulWidget {
  final DateTime Function() clock;

  const LeaderboardScreen({super.key, this.clock = DateTime.now});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  PersonalRecords _records = PersonalRecords.empty;

  @override
  void initState() {
    super.initState();
    StudySessionRepository.instance.revision.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    StudySessionRepository.instance.revision.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _records = computePersonalRecords(
        sessions: StudySessionRepository.instance.getAll(),
        scores: _loadScores(),
        streak: StorageService.getStreak(),
        streakRecord: StorageService.getStreakRecord(),
        notesCount: StorageService.getStudyNoteIds().length,
        now: widget.clock(),
      );
    });
  }

  List<MockScore> _loadScores() {
    return StorageService.getMockScoreIds()
        .map(StorageService.getMockScoreJson)
        .whereType<String>()
        .map((json) {
          try {
            return MockScore.fromJsonString(json);
          } catch (_) {
            return null;
          }
        })
        .whereType<MockScore>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.iosBackground,
      appBar: AppBar(
        title: const Text('Bảng vàng kỷ lục'),
        backgroundColor: AppColors.iosBackground,
        elevation: 0,
      ),
      body: SafeArea(
        child: _records.hasData ? _buildBoard() : _buildEmpty(),
      ),
    );
  }

  Widget _buildEmpty() {
    return EmptyStateView(
      icon: Icons.emoji_events_outlined,
      title: 'Chưa có kỷ lục nào',
      description:
          'Hoàn thành phiên học hoặc ghi điểm thi thử đầu tiên để mở Bảng vàng của riêng bạn.',
      actionLabel: 'Đóng',
      onAction: () => Navigator.of(context).maybePop(),
    );
  }

  Widget _buildBoard() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _PodiumHeader(records: _records),
        const SizedBox(height: 14),
        for (final record in _records.records) ...[
          _RecordCard(record: record),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        Text(
          'Bảng vàng chạy hoàn toàn trên thiết bị — không gửi dữ liệu học lên mạng.',
          style: AppTokens.caption.copyWith(color: AppColors.iosTextSecondary),
        ),
      ],
    );
  }
}

/// Khối đầu: huy chương và tổng quan nhanh.
class _PodiumHeader extends StatelessWidget {
  final PersonalRecords records;

  const _PodiumHeader({required this.records});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.iosStreak.withValues(alpha: 0.22),
            AppColors.iosPrimary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.iosStreak.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Text('🥇', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bảng vàng của bạn', style: AppTokens.heading2),
                const SizedBox(height: 4),
                Text(
                  '${records.totalSessions} phiên · ${formatStudyMinutes(records.totalMinutes)}',
                  style: AppTokens.body.copyWith(
                    color: AppColors.iosTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Một thẻ kỷ lục.
class _RecordCard extends StatelessWidget {
  final PersonalRecord record;

  const _RecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final highlight = record.highlight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.iosCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? AppColors.iosStreak : AppColors.iosSeparator,
          width: highlight ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: highlight
                  ? AppColors.iosStreak.withValues(alpha: 0.18)
                  : AppColors.iosFill,
              shape: BoxShape.circle,
            ),
            child: Text(record.emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: AppTokens.body.copyWith(fontWeight: FontWeight.w600),
                ),
                if (record.detail != null)
                  Text(
                    record.detail!,
                    style: AppTokens.caption
                        .copyWith(color: AppColors.iosTextSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            record.value,
            style: AppTokens.body.copyWith(
              fontWeight: FontWeight.w800,
              color: highlight ? AppColors.iosStreak : AppColors.iosPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

import '../../features/study/domain/models/study_models.dart';

/// Mức gợi ý về nhịp học, được suy ra *chỉ* từ tự đánh giá tùy chọn sau phiên.
/// Không phải chẩn đoán tâm lý hay kết luận về trạng thái sức khỏe.
enum StudyWellbeingState { unknown, steady, gentle }

class StudyWellbeingSignal {
  const StudyWellbeingSignal({required this.state, required this.guidance});

  final StudyWellbeingState state;
  final String guidance;
}

class StudyWellbeingDetector {
  StudyWellbeingDetector._();

  static StudyWellbeingSignal detect(
    Iterable<StudySession> sessions, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final rated = sessions
        .where((s) => reference.difference(s.completedAt).inDays >= 0)
        .where((s) => reference.difference(s.completedAt).inDays <= 7)
        .where((s) => s.mood != null || s.focus != null)
        .toList();
    if (rated.length < 3) {
      return const StudyWellbeingSignal(
        state: StudyWellbeingState.unknown,
        guidance: '',
      );
    }

    final moodScores = rated.where((s) => s.mood != null).map((s) => s.mood!);
    final focusScores =
        rated.where((s) => s.focus != null).map((s) => s.focus!);
    final averageMood = moodScores.isEmpty
        ? null
        : moodScores.reduce((a, b) => a + b) / moodScores.length;
    final averageFocus = focusScores.isEmpty
        ? null
        : focusScores.reduce((a, b) => a + b) / focusScores.length;

    if ((averageMood != null && averageMood <= 2.5) ||
        (averageFocus != null && averageFocus <= 2.25)) {
      return const StudyWellbeingSignal(
        state: StudyWellbeingState.gentle,
        guidance:
            'Nhịp tự đánh giá gần đây đang thấp. Gợi ý phiên ngắn, một việc ưu tiên và giọng điệu động viên; không tăng áp lực hay dồn thêm task.',
      );
    }
    return const StudyWellbeingSignal(
      state: StudyWellbeingState.steady,
      guidance:
          'Nhịp tự đánh giá gần đây ổn định. Có thể duy trì kế hoạch hiện tại.',
    );
  }
}

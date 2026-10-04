import '../../features/study/domain/repositories/study_session_repository.dart';

class ScheduledDay {
  final DateTime date;
  final List<ScheduledTask> tasks;
  final int totalMinutes;

  ScheduledDay(this.date, this.tasks, this.totalMinutes);
}

class ScheduledTask {
  final String title;
  final String subject;
  final int minutes;
  final String priority;

  ScheduledTask(this.title, this.subject, this.minutes, this.priority);
}

class AutoSchedulerService {
  static List<ScheduledDay> generateWeekPlan({DateTime? now}) {
    final t = now ?? DateTime.now();
    final sessions = StudySessionRepository.instance.getAll();

    final subjects = _extractSubjects(sessions);

    final days = <ScheduledDay>[];
    for (var i = 0; i < 7; i++) {
      final date = t.add(Duration(days: i));
      final tasks = _generateDayTasks(subjects);
      final totalMinutes = tasks.fold<int>(0, (a, t) => a + t.minutes);
      days.add(ScheduledDay(date, tasks, totalMinutes));
    }
    return days;
  }

  static List<String> _extractSubjects(List sessions) {
    final subjects = <String>{};
    for (final s in sessions) {
      if (s.subject.isNotEmpty) subjects.add(s.subject);
    }
    if (subjects.isEmpty) return ['Toán', 'Vật lý', 'Hóa học'];
    return subjects.toList();
  }

  static List<ScheduledTask> _generateDayTasks(List<String> subjects) {
    final tasks = <ScheduledTask>[];
    var remainingMinutes = 90;

    for (final subject in subjects) {
      if (remainingMinutes <= 0) break;
      final minutes = remainingMinutes >= 45 ? 45 : remainingMinutes;
      tasks.add(ScheduledTask(
        'Ôn $subject',
        subject,
        minutes,
        'high',
      ));
      remainingMinutes -= minutes;
    }

    return tasks;
  }
}

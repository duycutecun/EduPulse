import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/services/audio_synth_service.dart';

/// Định nghĩa phụ kiện trong tủ đồ Mascot
class MascotAccessoryItem {
  final String id;
  final String name;
  final String icon;
  final String description;
  final int minStreak;
  final bool requiresAllTasks;

  const MascotAccessoryItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    this.minStreak = 0,
    this.requiresAllTasks = false,
  });
}

const List<MascotAccessoryItem> kMascotAccessories = [
  MascotAccessoryItem(
    id: 'sprout',
    name: 'Mầm cây',
    icon: '🌿',
    description: 'Ươm mầm tri thức mỗi ngày',
    minStreak: 0,
  ),
  MascotAccessoryItem(
    id: 'grad_cap',
    name: 'Mũ cử nhân',
    icon: '🎓',
    description: 'Chinh phục cánh cổng đại học (Streak 3 ngày)',
    minStreak: 3,
  ),
  MascotAccessoryItem(
    id: 'crown',
    name: 'Vương miện',
    icon: '👑',
    description: 'Khí chất thủ khoa (Streak 7 ngày)',
    minStreak: 7,
  ),
  MascotAccessoryItem(
    id: 'glasses',
    name: 'Kính râm',
    icon: '🕶️',
    description: 'Bình tĩnh trước mọi đề khó (Streak 14 ngày)',
    minStreak: 14,
  ),
  MascotAccessoryItem(
    id: 'sakura',
    name: 'Hoa anh đào',
    icon: '🌸',
    description: 'Đơm hoa kết trái đỗ đạt (Streak 21 ngày)',
    minStreak: 21,
  ),
  MascotAccessoryItem(
    id: 'boba',
    name: 'Trà sữa',
    icon: '☕',
    description: 'Nạp năng lượng hoàn thành 100% mục tiêu ngày',
    requiresAllTasks: true,
  ),
];

/// Modal tương tác Cấp 3: "Góc Tâm Tình Cùng Linh Vật Sĩ Tử"
class MascotCompanionModal extends StatefulWidget {
  final int streak;
  final bool isAllTasksCompleted;
  final VoidCallback onAccessoryChanged;

  const MascotCompanionModal({
    super.key,
    required this.streak,
    required this.isAllTasksCompleted,
    required this.onAccessoryChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required int streak,
    required bool isAllTasksCompleted,
    required VoidCallback onAccessoryChanged,
  }) {
    AudioSynthService.playChirp();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MascotCompanionModal(
        streak: streak,
        isAllTasksCompleted: isAllTasksCompleted,
        onAccessoryChanged: onAccessoryChanged,
      ),
    );
  }

  @override
  State<MascotCompanionModal> createState() => _MascotCompanionModalState();
}

class _MascotCompanionModalState extends State<MascotCompanionModal> {
  late String _equippedAccessory;
  late int _bondExp;
  String? _todayFortune;
  bool _isDrawingFortune = false;

  final List<String> _fortunes = [
    '🌟 Quẻ Đại Cát: Hôm nay giải đề trúng tủ, công thức nhớ sâu! Tự tin 9+!',
    '🎯 Quẻ Thượng Cát: Đầu óc minh mẫn phi thường, không bị bẫy đề thi lừa!',
    '⚡ Quẻ Tinh Thông: 25 phút Pomodoro hôm nay bằng 2 tiếng ngày thường!',
    '🚀 Quẻ Thăng Tiến: Kiên trì mỗi ngày là giấy báo nhập học nguyện vọng 1!',
    '🌿 Quẻ An Nhiên: Giữ tâm bất biến giữa dòng đề khó, làm chắc từng câu một!',
    '🌸 Quẻ May Mắn: Thần may mắn mỉm cười, khoanh trắc nghiệm câu nào chuẩn câu đó!',
  ];

  @override
  void initState() {
    super.initState();
    _equippedAccessory = StorageService.getMascotAccessory();
    _bondExp = StorageService.getMascotBondExp();
    _loadFortune();
  }

  void _loadFortune() {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = StorageService.getLastFortuneDate();
    if (lastDate == todayStr) {
      _todayFortune = StorageService.getLastFortuneText();
    }
  }

  void _drawFortune() {
    if (_isDrawingFortune) return;
    setState(() => _isDrawingFortune = true);
    AudioSynthService.playPop();

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final fortune = _fortunes[math.Random().nextInt(_fortunes.length)];
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      StorageService.setLastFortuneDate(todayStr);
      StorageService.setLastFortuneText(fortune);
      StorageService.addMascotBondExp(25);

      AudioSynthService.playEquip();
      setState(() {
        _todayFortune = fortune;
        _isDrawingFortune = false;
        _bondExp = StorageService.getMascotBondExp();
      });
    });
  }

  void _selectAccessory(MascotAccessoryItem item) {
    // Check unlock condition
    final isUnlocked = (item.minStreak <= widget.streak) &&
        (!item.requiresAllTasks || widget.isAllTasksCompleted);

    if (!isUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item.requiresAllTasks
                ? '⚠️ Cần hoàn thành 100% nhiệm vụ hôm nay để mở khóa!'
                : '⚠️ Cần đạt chuỗi ${item.minStreak} ngày học để mở khóa!',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    AudioSynthService.playEquip();
    StorageService.setMascotAccessory(item.id);
    setState(() => _equippedAccessory = item.id);
    widget.onAccessoryChanged();
  }

  void _onPetMascot() {
    AudioSynthService.playChirp();
  }

  void _buyStreakFreeze() {
    const cost = 100;
    if (StorageService.getMascotBondExp() < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn chưa đủ EXP — hãy hoàn thành nhiệm vụ & Pomodoro!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (StorageService.getStreakFreezes() >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn đã giữ tối đa 3 lá bùa!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final ok = StorageService.buyStreakFreeze();
    AudioSynthService.playEquip();
    setState(() => _bondExp = StorageService.getMascotBondExp());
    if (mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛡️ Đã mua lá bùa giữ chuỗi!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bondLevel = (_bondExp ~/ 100) + 1;
    final progressInLevel = (_bondExp % 100) / 100.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Góc Tâm Tình Sĩ Tử 💖',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Chạm xoa đầu hoặc bốc quẻ may mắn cùng bạn Cú!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  color: AppColors.textMuted,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Large Interactive Mascot Preview
            GestureDetector(
              onTap: _onPetMascot,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                    // Aura circle
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.green.withValues(alpha: 0.15),
                        border: Border.all(color: AppColors.green, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.green.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          'assets/images/mascot.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    // Equipped Accessory Badge
                    Positioned(
                      top: -6,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.orange, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          kMascotAccessories
                              .firstWhere(
                                (a) => a.id == _equippedAccessory,
                                orElse: () => kMascotAccessories.first,
                              )
                              .icon,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),

                    // Pet hint
                    Positioned(
                      bottom: -10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Chạm để xoa đầu ✨',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
              ),
            ),
            const SizedBox(height: 26),

            // Bond Level Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('💖', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(
                            'Cấp Thân Thiết: Lv.$bondLevel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$_bondExp EXP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progressInLevel,
                      minHeight: 8,
                      backgroundColor: AppColors.border,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.green),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hoàn thành Pomodoro & nhiệm vụ để tăng cấp gắn kết!',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Streak Freeze (Lá bùa giữ chuỗi)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.blue, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                        child: Text('🛡️', style: TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lá bùa giữ chuỗi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Nghỉ 1 ngày không mất streak 🔥 • Đang giữ: ${StorageService.getStreakFreezes()}/3',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _buyStreakFreeze,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '100 EXP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Daily Fortune Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.orange.withValues(alpha: 0.12),
                    AppColors.yellow.withValues(alpha: 0.18),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.orange, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('🥠', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Text(
                            'Quẻ May Mắn Mỗi Ngày',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      if (_todayFortune != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Đã bốc hôm nay',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_todayFortune != null)
                    Text(
                      _todayFortune!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mỗi ngày bốc một quẻ để nhận lời khuyên tâm lý và vận may học tập!',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isDrawingFortune ? null : _drawFortune,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: _isDrawingFortune
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome_rounded),
                            label: Text(
                              _isDrawingFortune
                                  ? 'Đang xin quẻ...'
                                  : 'Bốc Quẻ Sĩ Tử (+25 EXP)',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Wardrobe Accessory Picker
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tủ Đồ Phụ Kiện Sĩ Tử 🎒',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.95,
              ),
              itemCount: kMascotAccessories.length,
              itemBuilder: (context, index) {
                final item = kMascotAccessories[index];
                final isSelected = _equippedAccessory == item.id;
                final isUnlocked = (item.minStreak <= widget.streak) &&
                    (!item.requiresAllTasks || widget.isAllTasksCompleted);

                return GestureDetector(
                  onTap: () => _selectAccessory(item),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.green.withValues(alpha: 0.14)
                          : (isUnlocked
                              ? AppColors.bgPage
                              : AppColors.border.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.green : AppColors.border,
                        width: isSelected ? 2.5 : 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              item.icon,
                              style: TextStyle(
                                fontSize: 30,
                                color: isUnlocked ? null : Colors.grey,
                              ),
                            ),
                            if (!isUnlocked)
                              Positioned(
                                right: -4,
                                bottom: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.lock_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.green
                                : (isUnlocked
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isSelected
                              ? 'Đang đeo'
                              : (isUnlocked
                                  ? 'Sẵn sàng'
                                  : (item.requiresAllTasks
                                      ? 'Hết task'
                                      : '${item.minStreak}d streak')),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppColors.green
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

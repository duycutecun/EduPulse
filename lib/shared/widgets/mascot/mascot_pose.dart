/// Các trạng thái biểu cảm của linh vật mèo Cú Sĩ tử.
///
/// Trước đây enum này sống trong `mascot_avatar.dart`; được chuyển về đây cùng
/// với `MascotPose` để mọi bộ phận vẽ/hoạt hình dùng chung một nguồn sự thật.
enum MascotMood {
  idle, // // Trạng thái thở bồng bềnh bình thường
  focus, // Tập trung học tập Pomodoro
  excited, // Phấn khích khi hoàn thành bài tập / tap combo
  relax, // Thư giãn nghỉ ngơi giữa hiệp
  sleepy, // Buồn ngủ khi quá khuya
  celebrate, // Ăn mừng streak hoặc hoàn thành toàn bộ mục tiêu ngày
}

/// Dữ liệu thuần để "dẫn động" từng bộ phận của mèo trong [MascotPainter].
///
/// Mọi hình học trong painter đều là hàm của [MascotPose] — thay đổi pose là
/// thay đổi biểu cảm/trạng thái; controller animation chỉ cần nối vào các
/// trường này, không cần viết lại đường vẽ.
class MascotPose {
  const MascotPose({
    this.headSquash = 1.0,
    this.headTilt = 0.0,
    this.leftEar = 0.0,
    this.rightEar = 0.0,
    this.eyeOpen = 1.0,
    this.eyeHappy = 0.0,
    this.browLift = 0.0,
    this.mouthOpen = 0.0,
    this.mouthSmile = 0.0,
    this.blushOpacity = 0.0,
    this.pawLift = 0.0,
    this.tailWag = 0.0,
    this.bodyDrop = 0.0,
  });

  /// Độ bẹp/giãn dọc toàn thân: 1.0 = nguyên vẹn, >1 = "squash" bẹp xuống,
  /// <1 = "stretch" vươn cao. Dùng cho hiệu ứng chạm.
  final double headSquash;

  /// Góc nghiêng đầu (radian).
  final double headTilt;

  /// Độ nhấc tai trái / phải (-1..1): >0 tai vểnh lên, <0 tai cụp xuống.
  final double leftEar;
  final double rightEar;

  /// Độ mở mắt (0..1): 1 = mắt tròn mở, 0 = nhắm (blink/sleep).
  final double eyeOpen;

  /// Độ "mắt ^ ^" (0..1): càng cao mắt cong lên kiểu hạnh phúc.
  final double eyeHappy;

  /// Độ nhướn nhíu lông mày (-1 nhíu, 0 thường, 1 nhướn cao).
  final double browLift;

  /// Độ mở miệng (0..1).
  final double mouthOpen;

  /// Độ cười của miệng (0..1).
  final double mouthSmile;

  /// Độ hiện má hồng (0..1).
  final double blushOpacity;

  /// Độ giơ chân trước lên (0..1) — khi vẫy chào/tap.
  final double pawLift;

  /// Độ vẫy đuôi (0..1).
  final double tailWag;

  /// Độ trũng thân xuống (0..1) — khi buồn ngủ.
  final double bodyDrop;

  /// Biểu cảm mặc định theo [MascotMood].
  static MascotPose of(MascotMood mood) {
    switch (mood) {
      case MascotMood.idle:
        return const MascotPose(
          eyeOpen: 1.0,
          mouthSmile: 0.4,
          blushOpacity: 0.5,
        );
      case MascotMood.focus:
        return const MascotPose(
          eyeOpen: 1.0,
          browLift: -1.0,
          mouthSmile: 0.2,
          leftEar: 0.2,
          rightEar: 0.2,
          blushOpacity: 0.4,
        );
      case MascotMood.excited:
        return const MascotPose(
          eyeOpen: 1.0,
          eyeHappy: 0.3,
          mouthOpen: 0.4,
          mouthSmile: 0.9,
          leftEar: 0.5,
          rightEar: 0.5,
          blushOpacity: 0.8,
          tailWag: 0.6,
        );
      case MascotMood.relax:
        return const MascotPose(
          eyeOpen: 0.55,
          mouthSmile: 0.7,
          blushOpacity: 0.6,
          headTilt: -0.02,
        );
      case MascotMood.sleepy:
        return const MascotPose(
          eyeOpen: 0.12,
          mouthSmile: 0.2,
          blushOpacity: 0.3,
          headTilt: -0.03,
          bodyDrop: 0.4,
        );
      case MascotMood.celebrate:
        return const MascotPose(
          eyeOpen: 1.0,
          eyeHappy: 1.0,
          mouthOpen: 0.5,
          mouthSmile: 1.0,
          leftEar: 0.6,
          rightEar: 0.6,
          blushOpacity: 0.9,
          tailWag: 1.0,
          pawLift: 0.5,
        );
    }
  }

  MascotPose copyWith({
    double? headSquash,
    double? headTilt,
    double? leftEar,
    double? rightEar,
    double? eyeOpen,
    double? eyeHappy,
    double? browLift,
    double? mouthOpen,
    double? mouthSmile,
    double? blushOpacity,
    double? pawLift,
    double? tailWag,
    double? bodyDrop,
  }) {
    return MascotPose(
      headSquash: headSquash ?? this.headSquash,
      headTilt: headTilt ?? this.headTilt,
      leftEar: leftEar ?? this.leftEar,
      rightEar: rightEar ?? this.rightEar,
      eyeOpen: eyeOpen ?? this.eyeOpen,
      eyeHappy: eyeHappy ?? this.eyeHappy,
      browLift: browLift ?? this.browLift,
      mouthOpen: mouthOpen ?? this.mouthOpen,
      mouthSmile: mouthSmile ?? this.mouthSmile,
      blushOpacity: blushOpacity ?? this.blushOpacity,
      pawLift: pawLift ?? this.pawLift,
      tailWag: tailWag ?? this.tailWag,
      bodyDrop: bodyDrop ?? this.bodyDrop,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MascotPose &&
      other.headSquash == headSquash &&
      other.headTilt == headTilt &&
      other.leftEar == leftEar &&
      other.rightEar == rightEar &&
      other.eyeOpen == eyeOpen &&
      other.eyeHappy == eyeHappy &&
      other.browLift == browLift &&
      other.mouthOpen == mouthOpen &&
      other.mouthSmile == mouthSmile &&
      other.blushOpacity == blushOpacity &&
      other.pawLift == pawLift &&
      other.tailWag == tailWag &&
      other.bodyDrop == bodyDrop;

  @override
  int get hashCode => Object.hash(
        headSquash,
        headTilt,
        leftEar,
        rightEar,
        eyeOpen,
        eyeHappy,
        browLift,
        mouthOpen,
        mouthSmile,
        blushOpacity,
        pawLift,
        tailWag,
        bodyDrop,
      );
}
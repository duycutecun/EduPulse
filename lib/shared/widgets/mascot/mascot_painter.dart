import 'package:flutter/material.dart';
import 'mascot_palette.dart';
import 'mascot_pose.dart';

/// Vẽ linh vật mèo chibi bằng vector thuần Dart (không phụ thuộc ảnh).
///
/// Tái hiện icon hiện tại (`web/icons/Icon-512.png`): mèo chibi đang ngồi,
/// đầu tròn to, 2 tai tam giác nhọn, viền đen nét to, mắt đen tròn, mũi nâu,
/// 2 chân trước ở đáy. Mọi bộ phận là hàm của [MascotPose] nên chỉ cần chỉnh
/// pose là ra biểu cảm mới — không viết lại đường vẽ.
class MascotPainter extends CustomPainter {
  final MascotPose pose;

  const MascotPainter({required this.pose});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;

    _drawShadow(canvas, s);

    canvas.save();
    canvas.translate(0.5 * s, 0.55 * s);
    canvas.scale(1.0, pose.headSquash);
    canvas.translate(-0.5 * s, -0.55 * s);

    if (pose.tailWag > 0.05) {
      _drawTail(canvas, s);
    }
    _drawBody(canvas, s);
    _drawPaws(canvas, s);
    _drawHead(canvas, s);

    canvas.restore();
  }

  // ---------------------------------------------------------------- brushes

  Paint _outline(double s, {double factor = 1.0}) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * 0.022 * factor
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = MascotPalette.outline;

  Paint _stroke(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  Paint _fill(Color color) => Paint()..color = color;

  // ------------------------------------------------------------------ parts

  void _drawShadow(Canvas canvas, double s) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0.5 * s, 0.985 * s),
        width: 0.60 * s,
        height: 0.032 * s,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.08),
    );
  }

  void _drawTail(Canvas canvas, double s) {
    final wag = pose.tailWag;
    final tip = Offset(0.14 * s + wag * 0.04 * s, 0.64 * s - wag * 0.05 * s);
    final path = Path()
      ..moveTo(0.28 * s, 0.86 * s)
      ..quadraticBezierTo(
        0.10 * s,
        0.86 * s,
        tip.dx,
        tip.dy,
      );
    canvas.drawPath(path, _stroke(MascotPalette.outline, s * 0.10));
    canvas.drawPath(path, _stroke(MascotPalette.furMid, s * 0.06));
  }

  void _drawBody(Canvas canvas, double s) {
    final drop = pose.bodyDrop * 0.03 * s;
    canvas.save();
    canvas.translate(0, drop);

    // Lưng + outline
    final bodyRect = Rect.fromCenter(
      center: Offset(0.5 * s, 0.82 * s),
      width: 0.54 * s,
      height: 0.33 * s,
    );
    final bodyPath = Path()..addOval(bodyRect);
    canvas.drawPath(bodyPath, _fill(MascotPalette.furLight));
    canvas.drawPath(bodyPath, _outline(s));

    // Bụng sáng
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0.5 * s, 0.85 * s),
        width: 0.33 * s,
        height: 0.26 * s,
      ),
      _fill(MascotPalette.belly),
    );

    canvas.restore();
  }

  void _drawPaws(Canvas canvas, double s) {
    final lift = pose.pawLift * 0.10 * s;
    for (final dx in [0.42, 0.58]) {
      final cy = 0.945 * s - (dx == 0.58 ? lift : 0.0);
      final pawRect = Rect.fromCenter(
        center: Offset(dx * s, cy),
        width: 0.124 * s,
        height: 0.10 * s,
      );
      final pawPath = Path()..addOval(pawRect);
      canvas.drawPath(pawPath, _fill(MascotPalette.paw));
      canvas.drawPath(pawPath, _outline(s));

      // Ngón chân
      final toe = _stroke(MascotPalette.furDark, s * 0.008);
      canvas.drawLine(
        Offset((dx - 0.012) * s, cy - 0.018 * s),
        Offset((dx - 0.012) * s, cy + 0.012 * s),
        toe,
      );
      canvas.drawLine(
        Offset((dx + 0.012) * s, cy - 0.018 * s),
        Offset((dx + 0.012) * s, cy + 0.012 * s),
        toe,
      );
    }
  }

  void _drawHead(Canvas canvas, double s) {
    final headCenter = Offset(0.5 * s, 0.43 * s);
    final headRect = Rect.fromCenter(
      center: headCenter,
      width: 0.52 * s,
      height: 0.49 * s,
    );

    canvas.save();
    canvas.translate(headCenter.dx, headCenter.dy);
    canvas.rotate(pose.headTilt);
    canvas.translate(-headCenter.dx, -headCenter.dy);

    _drawEars(canvas, s);
    _drawFaceMask(canvas, s, headRect);
    _drawFace(canvas, s);

    canvas.restore();
  }

  Path _earPath(double s, Offset baseA, Offset baseB, Offset tip) {
    return Path()
      ..moveTo(baseA.dx, baseA.dy)
      ..quadraticBezierTo(
        (baseA.dx + tip.dx) / 2,
        baseA.dy - (baseA.dy - tip.dy) * 0.45,
        tip.dx,
        tip.dy,
      )
      ..quadraticBezierTo(
        (baseB.dx + tip.dx) / 2,
        baseB.dy - (baseB.dy - tip.dy) * 0.45,
        baseB.dx,
        baseB.dy,
      )
      ..close();
  }

  void _drawEars(Canvas canvas, double s) {
    // Tai trái
    _paintEar(
      canvas,
      s,
      baseA: Offset(0.362 * s, 0.215 * s),
      baseB: Offset(0.452 * s, 0.182 * s),
      tip: Offset(0.288 * s, 0.035 * s - pose.leftEar * 0.05 * s),
    );
    // Tai phải
    _paintEar(
      canvas,
      s,
      baseA: Offset(0.548 * s, 0.182 * s),
      baseB: Offset(0.638 * s, 0.215 * s),
      tip: Offset(0.712 * s, 0.035 * s - pose.rightEar * 0.05 * s),
    );
  }

  void _paintEar(
    Canvas canvas,
    double s, {
    required Offset baseA,
    required Offset baseB,
    required Offset tip,
  }) {
    final outer = _earPath(s, baseA, baseB, tip);
    canvas.drawPath(outer, _fill(MascotPalette.furLight));
    canvas.drawPath(outer, _outline(s));

    // Tai trong: hình tam giác thu nhỏ hướng về trọng tâm
    canvas.drawPath(
      _innerEarPath(baseA, baseB, tip, 0.55),
      _fill(MascotPalette.earInner),
    );
  }

  Path _innerEarPath(Offset a, Offset b, Offset tip, double factor) {
    final cx = (a.dx + b.dx + tip.dx) / 3;
    final cy = (a.dy + b.dy + tip.dy) / 3;
    Offset p(Offset v) =>
        Offset(cx + (v.dx - cx) * factor, cy + (v.dy - cy) * factor);
    return Path()
      ..moveTo(p(a).dx, p(a).dy)
      ..lineTo(p(b).dx, p(b).dy)
      ..lineTo(p(tip).dx, p(tip).dy)
      ..close();
  }

  void _drawFaceMask(Canvas canvas, double s, Rect headRect) {
    final headPath = Path()..addOval(headRect);
    canvas.drawPath(headPath, _fill(MascotPalette.furLight));
    canvas.drawPath(headPath, _outline(s));
  }

  void _drawFace(Canvas canvas, double s) {
    _drawEyes(canvas, s);
    _drawBrows(canvas, s);
    _drawBlush(canvas, s);
    _drawNose(canvas, s);
    _drawMouth(canvas, s);
    _drawWhiskers(canvas, s);
  }

  void _drawEyes(Canvas canvas, double s) {
    final open = pose.eyeOpen.clamp(0.0, 1.0);
    final r = 0.038 * s;
    final y = 0.435 * s;

    for (final cx in [0.41, 0.59]) {
      final center = Offset(cx * s, y);

      if (pose.eyeHappy > 0.5) {
        // Mắt ^^ (hạnh phúc)
        final happy = Path()
          ..moveTo(center.dx - r, center.dy)
          ..quadraticBezierTo(center.dx, center.dy - r * 1.3, center.dx + r, center.dy);
        canvas.drawPath(happy, _stroke(MascotPalette.outline, s * 0.012));
        continue;
      }

      if (open < 0.3) {
        // Mí mắt khép — nét ngang (ngủ / chớp)
        canvas.drawLine(
          Offset(center.dx - r, center.dy),
          Offset(center.dx + r, center.dy),
          _stroke(MascotPalette.outline, s * 0.010),
        );
        continue;
      }

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1.0, open);
      canvas.drawCircle(Offset.zero, r, _fill(MascotPalette.outline));
      canvas.restore();

      // Điểm sáng làm mắt "long lanh"
      if (open > 0.75) {
        canvas.drawCircle(
          Offset(center.dx - r * 0.38, center.dy - r * 0.38),
          r * 0.26,
          _fill(MascotPalette.eyeWhite),
        );
      }
    }
  }

  void _drawBrows(Canvas canvas, double s) {
    if (pose.browLift.abs() < 0.05) return;
    final brow = _stroke(MascotPalette.outline, s * 0.012);
    final lift = -pose.browLift * 0.016;

    canvas.drawLine(
      Offset(0.368 * s, (0.392 + lift) * s),
      Offset(0.440 * s, (0.402 + lift) * s),
      brow,
    );
    canvas.drawLine(
      Offset(0.560 * s, (0.402 + lift) * s),
      Offset(0.632 * s, (0.392 + lift) * s),
      brow,
    );
  }

  void _drawBlush(Canvas canvas, double s) {
    if (pose.blushOpacity <= 0.01) return;
    final blush = Color.fromRGBO(
      217,
      169,
      169,
      (0.35 * pose.blushOpacity).clamp(0.0, 1.0),
    );
    for (final cx in [0.345, 0.655]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx * s, 0.505 * s),
          width: 0.060 * s,
          height: 0.032 * s,
        ),
        _fill(blush),
      );
    }
  }

  void _drawNose(Canvas canvas, double s) {
    final nose = Path()
      ..moveTo(0.5 * s, 0.492 * s)
      ..quadraticBezierTo(0.480 * s, 0.512 * s, 0.5 * s, 0.522 * s)
      ..quadraticBezierTo(0.520 * s, 0.512 * s, 0.5 * s, 0.492 * s)
      ..close();
    canvas.drawPath(nose, _fill(MascotPalette.nose));
  }

  void _drawMouth(Canvas canvas, double s) {
    final smileY = -pose.mouthSmile * 0.012 * s;
    if (pose.mouthOpen > 0.4) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0.5 * s, (0.570 + (smileY / s)) * s),
          width: 0.030 * s,
          height: 0.024 * s * (0.6 + pose.mouthOpen),
        ),
        _fill(MascotPalette.outline),
      );
    }

    final mouth = Path()
      ..moveTo((0.5 - 0.038) * s, (0.568 + (smileY / s)) * s)
      ..quadraticBezierTo(
        0.5 * s,
        (0.545 + (smileY / s)) * s,
        0.5 * s,
        (0.572 + (smileY / s)) * s,
      )
      ..quadraticBezierTo(
        0.5 * s,
        (0.545 + (smileY / s)) * s,
        (0.5 + 0.038) * s,
        (0.568 + (smileY / s)) * s,
      );
    canvas.drawPath(mouth, _stroke(MascotPalette.outline, s * 0.009));
  }

  void _drawWhiskers(Canvas canvas, double s) {
    final whisker = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.008
      ..strokeCap = StrokeCap.round
      ..color = MascotPalette.outline.withValues(alpha: 0.45);

    const rows = [0.505, 0.520, 0.535];
    for (final dy in rows) {
      canvas.drawLine(
        Offset(0.365 * s, dy * s),
        Offset(0.290 * s, (dy - 0.012) * s),
        whisker,
      );
      canvas.drawLine(
        Offset(0.635 * s, dy * s),
        Offset(0.710 * s, (dy - 0.012) * s),
        whisker,
      );
    }
  }

  @override
  bool shouldRepaint(MascotPainter oldDelegate) =>
      oldDelegate.pose != pose;
}
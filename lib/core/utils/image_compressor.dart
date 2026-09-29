import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Nén ảnh trước khi gửi AI để tránh vượt giới hạn body (~4MB) của proxy
/// serverless. Chạy thuần Dart nên hoạt động tốt trên web/PWA (kể cả wasm).
class ImageCompressor {
  static const int maxDim = 1536;
  static const int targetBytes = 1500 * 1024; // ~1.5MB đích
  static const int minQuality = 55;

  /// Giảm kích thước cạnh dài xuống [maxDim] rồi encode lại thành JPEG.
  /// Trả về ảnh đã cồn nếu thành công (luôn nhỏ hơn hoặc bằng bản gốc), ngược
  /// lại trả về null để caller dùng ảnh gốc.
  static Future<Uint8List?> compress(Uint8List bytes) async {
    if (bytes.length <= targetBytes) return null; // ảnh nhỏ, khỏi nén
    try {
      // Decode khá nặng → chạy trong isolate riêng (nếu có môi trường isolate).
      final image = await _decode(bytes);
      if (image == null) return null;

      final w = image.width;
      final h = image.height;
      int nw = w;
      int nh = h;
      if (w > maxDim || h > maxDim) {
        if (w >= h) {
          nw = maxDim;
          nh = (h * maxDim / w).round();
        } else {
          nh = maxDim;
          nw = (w * maxDim / h).round();
        }
      }

      var work = image;
      if (nw != w || nh != h) {
        work = img.copyResize(
          image,
          width: nw,
          height: nh,
          interpolation: img.Interpolation.average,
        );
      }

      // Thử giảm dần chất lượng tới khi đạt kích thước đích.
      var quality = 82;
      Uint8List? best;
      while (quality >= minQuality) {
        best = Uint8List.fromList(
          img.encodeJpg(work, quality: quality),
        );
        if (best.length <= targetBytes) break;
        quality -= 9;
      }
      if (best != null && best.length < bytes.length) return best;
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<img.Image?> _decode(Uint8List bytes) async {
    return _runInBackground(() {
      try {
        return img.decodeImage(bytes);
      } catch (_) {
        return null;
      }
    });
  }

  /// Chạy khối tính toán nặng (decode/resize) — dùng Isolate nếu có, còn không
  /// thì chạy đồng bộ rồi bọc trong Future cho API nhất quán (web/wasm).
  static Future<T> _runInBackground<T>(T Function() compute) async {
    try {
      return await Isolate.run(compute);
    } catch (_) {
      return compute();
    }
  }
}
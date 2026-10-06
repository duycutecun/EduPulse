// Regenerate iOS AppIcon.appiconset from a single 1024x1024 source.
// Source: web/icons/Icon-512.png (EduPulse "EP" brand icon) — upsampled to
// 1024, then downscaled to every size AppIcon.appiconset/Contents.json needs.
//
// Run: dart run tool/generate_ios_icons.dart
import 'dart:io';
import 'package:image/image.dart' as img;

const String sourcePath = 'web/icons/Icon-512.png';
const String outDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

// (size, scale) pairs from Contents.json — pixel dimension = size * scale.
const List<(String, int, int)> icons = [
  // size, scale, pixels
  ('20x20', 1, 20),
  ('20x20', 2, 40),
  ('20x20', 3, 60),
  ('29x29', 1, 29),
  ('29x29', 2, 58),
  ('29x29', 3, 87),
  ('40x40', 1, 40),
  ('40x40', 2, 80),
  ('40x40', 3, 120),
  ('60x60', 2, 120),
  ('60x60', 3, 180),
  ('76x76', 1, 76),
  ('76x76', 2, 152),
  ('83.5x83.5', 2, 167),
  ('1024x1024', 1, 1024),
];

String fileNameFor(String size, int scale) {
  if (size == '1024x1024') return 'Icon-App-1024x1024@1x.png';
  // 83.5x83.5@2x has no @1x/@3x
  return 'Icon-App-$size@${scale}x.png';
}

void main() {
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Source not found: $sourcePath');
    exit(1);
  }
  final source = img.decodePng(sourceFile.readAsBytesSync());
  if (source == null) {
    stderr.writeln('Failed to decode $sourcePath');
    exit(1);
  }

  // Upscale 512 -> 1024 master (bicubic for smooth edges).
  final master = img.copyResize(
    source,
    width: 1024,
    height: 1024,
    interpolation: img.Interpolation.cubic,
  );

  final dir = Directory(outDir);
  if (!dir.existsSync()) {
    stderr.writeln('Missing dir: $outDir');
    exit(1);
  }

  for (final (size, scale, pixels) in icons) {
    final resized = pixels == 1024
        ? master
        : img.copyResize(
            master,
            width: pixels,
            height: pixels,
            interpolation: img.Interpolation.cubic,
          );

    // iOS marketing icon (1024) must have no alpha channel.
    final encoded = pixels == 1024
        ? img.encodePng(resized.convert(format: img.Format.uint8, numChannels: 3))
        : img.encodePng(resized);

    final name = fileNameFor(size, scale);
    File('$outDir/$name').writeAsBytesSync(encoded);
    stdout.writeln('Wrote $name (${pixels}x$pixels)');
  }
  stdout.writeln('Done. All icons regenerated from $sourcePath');
}

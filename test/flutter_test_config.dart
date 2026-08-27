import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Prevent GoogleFonts from attempting a real network fetch during tests
  // (the app bundles fonts at runtime; in tests there is no network).
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}

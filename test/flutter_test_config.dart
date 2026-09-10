import 'dart:async';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Font Nunito được bundle local (assets/fonts) nên test không cần network.
  await testMain();
}
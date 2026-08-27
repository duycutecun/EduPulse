import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/core/constants/app_colors.dart';

void main() {
  // Reproduces the mechanism used in lib/main.dart's _BrightnessSyncer: a
  // widget placed BELOW the MaterialApp Theme layer whose build depends on
  // Theme.of(context), so it rebuilds when the resolved theme brightness
  // changes and keeps AppColors.darkFallback in sync for the many static
  // color helpers called outside a build() context.
  Widget buildApp(ThemeMode mode) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      themeAnimationDuration: Duration.zero,
      home: Builder(
        builder: (context) {
          AppColors.darkFallback = Theme.of(context).brightness == Brightness.dark;
          return Scaffold(
            backgroundColor: AppColors.bgPage,
            body: Center(
              child: Text(
                AppColors.darkFallback ? 'dark-bg' : 'light-bg',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          );
        },
      ),
    );
  }

  test('theme-dependent colors resolve from the darkFallback flag', () {
    AppColors.darkFallback = true;
    expect(AppColors.bgPage, const Color(0xFF121F24));
    expect(AppColors.textPrimary, const Color(0xFFFFFFFF));
    expect(AppColors.border, const Color(0xFF3D464D));

    AppColors.darkFallback = false;
    expect(AppColors.bgPage, const Color(0xFFF7F7F7));
    expect(AppColors.textPrimary, const Color(0xFF4B4B4B));
    expect(AppColors.border, const Color(0xFFE5E5E5));
  });

  testWidgets('full app switch: dark -> light repaints bg + text instantly',
      (WidgetTester tester) async {
    // Start in dark
    await tester.pumpWidget(buildApp(ThemeMode.dark));
    expect(AppColors.darkFallback, isTrue);
    expect(AppColors.bgPage, const Color(0xFF121F24));
    expect(AppColors.textPrimary, const Color(0xFFFFFFFF));
    expect(find.text('dark-bg'), findsOneWidget);

    // Switch to light — the SAME tree, repainted immediately
    await tester.pumpWidget(buildApp(ThemeMode.light));
    await tester.pump(const Duration(milliseconds: 100));
    final actualThemeBrightness =
        Theme.of(tester.element(find.byType(Scaffold))).brightness;
    expect(actualThemeBrightness, Brightness.light,
        reason: 'MaterialApp must resolve light theme');
    expect(AppColors.darkFallback, isFalse,
        reason: 'darkFallback must follow the resolved theme');
    expect(AppColors.bgPage, const Color(0xFFF7F7F7));
    expect(AppColors.textPrimary, const Color(0xFF4B4B4B));
    expect(find.text('light-bg'), findsOneWidget);

    // And back to dark
    await tester.pumpWidget(buildApp(ThemeMode.dark));
    await tester.pump(const Duration(milliseconds: 100));
    expect(AppColors.darkFallback, isTrue);
    expect(find.text('dark-bg'), findsOneWidget);
  });

  testWidgets(
      'root sets darkFallback synchronously so one tap changes the WHOLE ui',
      (WidgetTester tester) async {
    // Reproduces lib/main.dart: the root state resolves dark BEFORE setState,
    // so the very first build of the switched frame reads the new colors.
    Future<void> switchMode(String mode, Brightness resolved) async {
      AppColors.darkFallback = resolved == Brightness.dark; // root _setThemeMode
      await tester.pumpWidget(buildApp(ThemeMode.values.firstWhere(
        (m) => m.name == mode,
        orElse: () => ThemeMode.dark,
      )));
    }

    // Start light
    await tester.pumpWidget(buildApp(ThemeMode.light));
    expect(find.text('light-bg'), findsOneWidget);

    // ONE switch to dark -> bg AND text must both change in the same frame.
    await switchMode('dark', Brightness.dark);
    expect(find.text('dark-bg'), findsOneWidget);
    expect(AppColors.bgPage, const Color(0xFF121F24));
    expect(AppColors.textPrimary, const Color(0xFFFFFFFF));
  });
}

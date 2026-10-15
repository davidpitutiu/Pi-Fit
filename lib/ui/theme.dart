import 'dart:ui';
import 'package:flutter/material.dart';

abstract final class PiColors {
  static const lime = Color(0xFFC7FF3D);
  static const mint = Color(0xFF79EEC6);
  static bool dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
  static Color muted(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;
  static Color line(BuildContext context) => dark(context)
      ? Colors.white.withValues(alpha: 0.10)
      : const Color(0xFF173D31).withValues(alpha: 0.09);
}

ThemeData piTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: PiColors.lime,
        brightness: brightness,
      ).copyWith(
        primary: dark ? PiColors.lime : const Color(0xFF3D6500),
        onPrimary: dark ? const Color(0xFF172400) : Colors.white,
        surface: dark ? const Color(0xFF192522) : const Color(0xFFFDFEFC),
        onSurface: dark ? const Color(0xFFF4F8F1) : const Color(0xFF15251E),
        onSurfaceVariant: dark
            ? const Color(0xFFA4B4AC)
            : const Color(0xFF61736A),
        outline: dark ? const Color(0xFF45564E) : const Color(0xFFBDCCC2),
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 21,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
        color: scheme.onSurface,
      ),
    ),
    dividerColor: scheme.onSurface.withValues(alpha: 0.08),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 35,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.65,
        color: scheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.13,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
        color: scheme.onSurface,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.65,
      ),
      titleMedium: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.5),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark
          ? Colors.white.withValues(alpha: 0.055)
          : Colors.white.withValues(alpha: 0.78),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide(color: scheme.primary, width: 1.3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PiColors.lime,
        foregroundColor: const Color(0xFF1D2B09),
        minimumSize: const Size(0, 51),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.17)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08)),
      backgroundColor: scheme.surface.withValues(alpha: 0.5),
      selectedColor: PiColors.lime.withValues(alpha: dark ? 0.17 : 0.27),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? const Color(0xFF12201B) : const Color(0xFFF1F6F0),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? const Color(0xFF192923) : const Color(0xFFF8FCF5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

/// Soft static gradients behind frosted cards preserve contrast and avoid motion.
class GlassBackground extends StatelessWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final dark = PiColors.dark(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF091310) : const Color(0xFFECF3ED),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -220,
            right: -190,
            width: 650,
            height: 700,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: dark
                      ? [
                          const Color(0xFF2F5945).withValues(alpha: 0.52),
                          Colors.transparent,
                        ]
                      : [const Color(0xFFD3EDBD), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            top: 350,
            left: -270,
            width: 680,
            height: 760,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: dark
                      ? [
                          const Color(0xFF1E4A48).withValues(alpha: 0.44),
                          Colors.transparent,
                        ]
                      : [
                          const Color(0xFFCCE8E7).withValues(alpha: 0.75),
                          Colors.transparent,
                        ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -200,
            right: -200,
            width: 640,
            height: 600,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: dark
                      ? [
                          const Color(0xFF32462A).withValues(alpha: 0.36),
                          Colors.transparent,
                        ]
                      : [
                          const Color(0xFFDFEECF).withValues(alpha: 0.75),
                          Colors.transparent,
                        ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class PiCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  const PiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.radius = 24,
  });
  @override
  Widget build(BuildContext context) {
    final dark = PiColors.dark(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [
                      Colors.white.withValues(alpha: 0.075),
                      const Color(0xFF1D3027).withValues(alpha: 0.30),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.88),
                      Colors.white.withValues(alpha: 0.49),
                    ],
            ),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.92),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeading({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 13),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

class PageBody extends StatelessWidget {
  final List<Widget> children;
  const PageBody({super.key, required this.children});
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    ),
  );
}

void toast(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));
String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
String formatTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

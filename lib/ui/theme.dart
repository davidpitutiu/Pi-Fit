import 'package:flutter/material.dart';

abstract final class PiColors {
  static const lime = Color(0xFFC7FF3D);
  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
  static Color muted(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;
}

ThemeData piTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: PiColors.lime,
        brightness: brightness,
      ).copyWith(
        primary: dark ? PiColors.lime : const Color(0xFF426600),
        onPrimary: const Color(0xFF182000),
        surface: dark ? const Color(0xFF1B1E23) : Colors.white,
        onSurface: dark ? const Color(0xFFF5F6F2) : const Color(0xFF141812),
        onSurfaceVariant: dark
            ? const Color(0xFF9DA49B)
            : const Color(0xFF626B60),
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF101216)
        : const Color(0xFFF3F5EF),
    fontFamily: 'Inter',
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF101216) : const Color(0xFFF3F5EF),
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    dividerColor: scheme.onSurface.withValues(alpha: 0.08),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 34,
        height: 1.12,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        color: scheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 27,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.7,
        color: scheme.onSurface,
      ),
      titleLarge: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.5),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PiColors.lime,
        foregroundColor: const Color(0xFF142000),
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: PiColors.lime.withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.all(
        TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      height: 76,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
      selectedColor: PiColors.lime.withValues(alpha: 0.23),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? const Color(0xFF171A1E) : const Color(0xFFF3F5EF),
      showDragHandle: true,
    ),
  );
}

class PiCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const PiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: PiColors.surface(context),
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
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
    padding: const EdgeInsets.only(top: 25, bottom: 14),
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
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    ),
  );
}

void toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
String formatTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

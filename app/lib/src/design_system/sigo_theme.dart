import 'package:flutter/material.dart';

class SigoThemeExtension extends ThemeExtension<SigoThemeExtension> {
  final Color surfaceBase;
  final Color surfaceRaised;
  final Color inkPrimary;
  final Color inkSecondary;
  final Color inkDisabled;
  final Color brandBlue;
  final Color brandGold;
  final Color actionBlue;
  final Color sidebar;
  final Color sidebarInk;
  final Color sidebarMuted;
  final Color headerStart;
  final Color headerEnd;
  final Color actionHover;
  final Color actionPressed;
  final Color focusLight;
  final Color focusSidebar;
  final Color focusHeader;
  final Color borderControl;
  final Color borderHairline;
  final Color danger;

  final Color lotOnTimeBg;
  final Color lotOnTimeInk;
  final Color lotDelayedBg;
  final Color lotDelayedInk;
  final Color lotPausedBg;
  final Color lotPausedInk;
  final Color lotCompleteBg;
  final Color lotCompleteInk;

  const SigoThemeExtension({
    required this.surfaceBase,
    required this.surfaceRaised,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.inkDisabled,
    required this.brandBlue,
    required this.brandGold,
    required this.actionBlue,
    required this.sidebar,
    required this.sidebarInk,
    required this.sidebarMuted,
    required this.headerStart,
    required this.headerEnd,
    required this.actionHover,
    required this.actionPressed,
    required this.focusLight,
    required this.focusSidebar,
    required this.focusHeader,
    required this.borderControl,
    required this.borderHairline,
    required this.danger,
    required this.lotOnTimeBg,
    required this.lotOnTimeInk,
    required this.lotDelayedBg,
    required this.lotDelayedInk,
    required this.lotPausedBg,
    required this.lotPausedInk,
    required this.lotCompleteBg,
    required this.lotCompleteInk,
  });

  @override
  SigoThemeExtension copyWith({
    Color? surfaceBase,
    Color? surfaceRaised,
    Color? inkPrimary,
    Color? inkSecondary,
    Color? inkDisabled,
    Color? brandBlue,
    Color? brandGold,
    Color? actionBlue,
    Color? sidebar,
    Color? sidebarInk,
    Color? sidebarMuted,
    Color? headerStart,
    Color? headerEnd,
    Color? actionHover,
    Color? actionPressed,
    Color? focusLight,
    Color? focusSidebar,
    Color? focusHeader,
    Color? borderControl,
    Color? borderHairline,
    Color? danger,
    Color? lotOnTimeBg,
    Color? lotOnTimeInk,
    Color? lotDelayedBg,
    Color? lotDelayedInk,
    Color? lotPausedBg,
    Color? lotPausedInk,
    Color? lotCompleteBg,
    Color? lotCompleteInk,
  }) {
    return SigoThemeExtension(
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      inkPrimary: inkPrimary ?? this.inkPrimary,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkDisabled: inkDisabled ?? this.inkDisabled,
      brandBlue: brandBlue ?? this.brandBlue,
      brandGold: brandGold ?? this.brandGold,
      actionBlue: actionBlue ?? this.actionBlue,
      sidebar: sidebar ?? this.sidebar,
      sidebarInk: sidebarInk ?? this.sidebarInk,
      sidebarMuted: sidebarMuted ?? this.sidebarMuted,
      headerStart: headerStart ?? this.headerStart,
      headerEnd: headerEnd ?? this.headerEnd,
      actionHover: actionHover ?? this.actionHover,
      actionPressed: actionPressed ?? this.actionPressed,
      focusLight: focusLight ?? this.focusLight,
      focusSidebar: focusSidebar ?? this.focusSidebar,
      focusHeader: focusHeader ?? this.focusHeader,
      borderControl: borderControl ?? this.borderControl,
      borderHairline: borderHairline ?? this.borderHairline,
      danger: danger ?? this.danger,
      lotOnTimeBg: lotOnTimeBg ?? this.lotOnTimeBg,
      lotOnTimeInk: lotOnTimeInk ?? this.lotOnTimeInk,
      lotDelayedBg: lotDelayedBg ?? this.lotDelayedBg,
      lotDelayedInk: lotDelayedInk ?? this.lotDelayedInk,
      lotPausedBg: lotPausedBg ?? this.lotPausedBg,
      lotPausedInk: lotPausedInk ?? this.lotPausedInk,
      lotCompleteBg: lotCompleteBg ?? this.lotCompleteBg,
      lotCompleteInk: lotCompleteInk ?? this.lotCompleteInk,
    );
  }

  @override
  SigoThemeExtension lerp(ThemeExtension<SigoThemeExtension>? other, double t) {
    if (other is! SigoThemeExtension) {
      return this;
    }
    return SigoThemeExtension(
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      inkPrimary: Color.lerp(inkPrimary, other.inkPrimary, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkDisabled: Color.lerp(inkDisabled, other.inkDisabled, t)!,
      brandBlue: Color.lerp(brandBlue, other.brandBlue, t)!,
      brandGold: Color.lerp(brandGold, other.brandGold, t)!,
      actionBlue: Color.lerp(actionBlue, other.actionBlue, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      sidebarInk: Color.lerp(sidebarInk, other.sidebarInk, t)!,
      sidebarMuted: Color.lerp(sidebarMuted, other.sidebarMuted, t)!,
      headerStart: Color.lerp(headerStart, other.headerStart, t)!,
      headerEnd: Color.lerp(headerEnd, other.headerEnd, t)!,
      actionHover: Color.lerp(actionHover, other.actionHover, t)!,
      actionPressed: Color.lerp(actionPressed, other.actionPressed, t)!,
      focusLight: Color.lerp(focusLight, other.focusLight, t)!,
      focusSidebar: Color.lerp(focusSidebar, other.focusSidebar, t)!,
      focusHeader: Color.lerp(focusHeader, other.focusHeader, t)!,
      borderControl: Color.lerp(borderControl, other.borderControl, t)!,
      borderHairline: Color.lerp(borderHairline, other.borderHairline, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      lotOnTimeBg: Color.lerp(lotOnTimeBg, other.lotOnTimeBg, t)!,
      lotOnTimeInk: Color.lerp(lotOnTimeInk, other.lotOnTimeInk, t)!,
      lotDelayedBg: Color.lerp(lotDelayedBg, other.lotDelayedBg, t)!,
      lotDelayedInk: Color.lerp(lotDelayedInk, other.lotDelayedInk, t)!,
      lotPausedBg: Color.lerp(lotPausedBg, other.lotPausedBg, t)!,
      lotPausedInk: Color.lerp(lotPausedInk, other.lotPausedInk, t)!,
      lotCompleteBg: Color.lerp(lotCompleteBg, other.lotCompleteBg, t)!,
      lotCompleteInk: Color.lerp(lotCompleteInk, other.lotCompleteInk, t)!,
    );
  }
}

class SigoTheme {
  static const SigoThemeExtension extension = SigoThemeExtension(
    surfaceBase: Color(0xFFF8FAFC),
    surfaceRaised: Color(0xFFFFFFFF),
    inkPrimary: Color(0xFF0F172A),
    inkSecondary: Color(0xFF475569),
    inkDisabled: Color(0xFF94A3B8),
    brandBlue: Color(0xFF2196F3),
    brandGold: Color(0xFFFCA906),
    actionBlue: Color(0xFF1565C0),
    sidebar: Color(0xFF082344),
    sidebarInk: Color(0xFFFFFFFF),
    sidebarMuted: Color(0xFFCBD5E1),
    headerStart: Color(0xFF0D47A1),
    headerEnd: Color(0xFF1565C0),
    actionHover: Color(0xFF0D47A1),
    actionPressed: Color(0xFF0B3A82),
    focusLight: Color(0xFF1565C0),
    focusSidebar: Color(0xFFFCA906),
    focusHeader: Color(0xFFFFFFFF),
    borderControl: Color(0xFF64748B),
    borderHairline: Color(0xFFE2E8F0),
    danger: Color(0xFFDC2626),
    lotOnTimeBg: Color(0xFFF0FDF4),
    lotOnTimeInk: Color(0xFF166534),
    lotDelayedBg: Color(0xFFFEF2F2),
    lotDelayedInk: Color(0xFF991B1B),
    lotPausedBg: Color(0xFFFFF7ED),
    lotPausedInk: Color(0xFF9A3412),
    lotCompleteBg: Color(0xFFEFF6FF),
    lotCompleteInk: Color(0xFF1E40AF),
  );

  static ThemeData get lightTheme {
    final textTheme =
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 40,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ), // page-desktop
          displayMedium: TextStyle(
            fontSize: 28,
            height: 1.28,
            fontWeight: FontWeight.w700,
          ), // page-mobile
          displaySmall: TextStyle(
            fontSize: 24,
            height: 1.33,
            fontWeight: FontWeight.w700,
          ), // section
          titleLarge: TextStyle(
            fontSize: 20,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ), // constructor-name
          titleMedium: TextStyle(
            fontSize: 18,
            height: 1.33,
            fontWeight: FontWeight.w600,
          ), // lot-name
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ), // reading
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.42,
            fontWeight: FontWeight.w400,
          ), // supporting
          labelLarge: TextStyle(
            fontSize: 14,
            height: 1.42,
            fontWeight: FontWeight.w600,
          ), // action
        ).apply(
          bodyColor: extension.inkPrimary,
          displayColor: extension.inkPrimary,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: extension.actionBlue,
        primary: extension.actionBlue,
        secondary: extension.brandGold,
        surface: extension.surfaceBase,
        error: extension.danger,
        onSurface: extension.inkPrimary,
        onPrimary: extension.surfaceRaised,
      ),
      scaffoldBackgroundColor: extension.surfaceBase,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[extension],
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: extension.actionBlue,
          foregroundColor: extension.surfaceRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // rounded.sm
          ),
          minimumSize: const Size(48, 48), // touch-min
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderSide: BorderSide(color: extension.borderControl),
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: extension.borderControl),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: extension.focusLight, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: extension.danger),
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: TextStyle(color: extension.inkSecondary),
      ),
    );
  }
}

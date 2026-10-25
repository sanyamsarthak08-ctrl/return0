import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models.dart';

/// All colour tokens from the HTML (:root vars), light + dark.
@immutable
class CC extends ThemeExtension<CC> {
  final Color bg, surface, surface2, ink, ink2, ink3, line, line2;
  final Color accent, accentInk, accentSoft;
  final Color coin, coinSoft, coinInk;
  final Color ok, okSoft, bad, badSoft;
  final Color b1, b2, b3, b4, onB;

  const CC({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.line2,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.coin,
    required this.coinSoft,
    required this.coinInk,
    required this.ok,
    required this.okSoft,
    required this.bad,
    required this.badSoft,
    required this.b1,
    required this.b2,
    required this.b3,
    required this.b4,
    required this.onB,
  });

  // Updated to match the Pirate Cove Light Theme
  static const light = CC(
    bg: Color(0xFFE9D9B5),
    surface: Color(0xFFF6E9C9),
    surface2: Color(0xFFEBDAB3),
    ink: Color(0xFF2B1A0E),
    ink2: Color(0xFF5A3F27),
    ink3: Color(0xFF7A5B3E),
    line: Color(0xFFCDB387),
    line2: Color(0xFFB8975F),
    accent: Color(0xFF9E1B1B),
    accentInk: Color(0xFFFFF4DC),
    accentSoft: Color(0xFFF1D3C2),
    coin: Color(0xFFD4A017),
    coinSoft: Color(0xFFF6E4A6),
    coinInk: Color(0xFF5E4300),
    ok: Color(0xFF1F6B4A),
    okSoft: Color(0xFFD5E6C9),
    bad: Color(0xFFA3201B),
    badSoft: Color(0xFFF0CFC4),
    b1: Color(0xFF1D5C7A),
    b2: Color(0xFF9E1B1B),
    b3: Color(0xFF5B3A78),
    b4: Color(0xFF1F6B4A),
    onB: Color(0xFFF6E9C9),
  );

  // Updated to match the Pirate Cove Dark Theme
  static const dark = CC(
    bg: Color(0xFF07151F),
    surface: Color(0xFF0E2433),
    surface2: Color(0xFF12303F),
    ink: Color(0xFFF2E6C8),
    ink2: Color(0xFFCBB98E),
    ink3: Color(0xFFA39368),
    line: Color(0xFF1E4256),
    line2: Color(0xFF2B5870),
    accent: Color(0xFFE5483A),
    accentInk: Color(0xFF1E0805),
    accentSoft: Color(0xFF3A1713),
    coin: Color(0xFFFFC83D),
    coinSoft: Color(0xFF3B2E0B),
    coinInk: Color(0xFFFFD875),
    ok: Color(0xFF4FD1A0),
    okSoft: Color(0xFF0F3A2C),
    bad: Color(0xFFFF7A6B),
    badSoft: Color(0xFF3B1613),
    b1: Color(0xFF1D5C7A),
    b2: Color(0xFF9E1B1B),
    b3: Color(0xFF5B3A78),
    b4: Color(0xFF1F6B4A),
    onB: Color(0xFF07151F),
  );

  Color kind(Kind k) => switch (k) {
    Kind.design => b2,
    Kind.frontend => b1,
    Kind.backend => b4,
    Kind.copy => b3,
    Kind.qa => ink2,
  };

  Color branch(int n) => [b1, b2, b3, b4][(n - 1) % 4];

  @override
  CC copyWith() => this;
  @override
  CC lerp(ThemeExtension<CC>? other, double t) => t < .5 ? this : (other as CC);
}

extension CtxX on BuildContext {
  CC get cc => Theme.of(this).extension<CC>()!;
}

extension ColorX on Color {
  /// Same colour at a given opacity (0..1).
  Color o(double a) => withAlpha((a * 255).round());
}

/// Fonts updated to Pirate Cove style: Pirata One (display), IM Fell English (body), IBM Plex Mono (numbers).
class T {
  static TextStyle disp(
    double s, {
    FontWeight w = FontWeight.w600,
    Color? color,
    double? h,
  }) => GoogleFonts.pirataOne(
    fontSize: s,
    fontWeight: w,
    color: color,
    height: h,
  );
  static TextStyle body(
    double s, {
    FontWeight w = FontWeight.w400,
    Color? color,
    double? h,
    double? ls,
  }) => GoogleFonts.imFellEnglish(
    fontSize: s,
    fontWeight: w,
    color: color,
    height: h,
    letterSpacing: ls,
  );
  static TextStyle mono(
    double s, {
    FontWeight w = FontWeight.w500,
    Color? color,
    double? h,
  }) => GoogleFonts.ibmPlexMono(
    fontSize: s,
    fontWeight: w,
    color: color,
    height: h,
  );
}

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.light ? CC.light : CC.dark;
  final scheme = ColorScheme(
    brightness: b,
    primary: c.accent,
    onPrimary: c.accentInk,
    secondary: c.ink,
    onSecondary: c.bg,
    error: c.bad,
    onError: c.bg,
    surface: c.surface,
    onSurface: c.ink,
  );

  // Pirate "wooden plank" button look: rounded corners, dark outline, blackletter label.
  final btnLabel = T.disp(17, w: FontWeight.w400).copyWith(letterSpacing: 0.5);
  const btnPad = EdgeInsets.symmetric(horizontal: 20, vertical: 12);
  RoundedRectangleBorder plank(Color border, {double width = 1.5}) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: border, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    dividerColor: c.line,
    textTheme: GoogleFonts.imFellEnglishTextTheme(
      ThemeData(brightness: b).textTheme,
    ).apply(bodyColor: c.ink, displayColor: c.ink),
    extensions: [c],
    splashFactory: NoSplash.splashFactory,

    // Main action buttons (Claim, Submit, Set Sail...)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.accentInk,
        elevation: 3,
        shadowColor: c.ink.o(.45),
        padding: btnPad,
        textStyle: btnLabel,
        shape: plank(c.ink),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.accentInk,
        elevation: 3,
        shadowColor: c.ink.o(.45),
        padding: btnPad,
        textStyle: btnLabel,
        shape: plank(c.ink),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        backgroundColor: c.surface.o(.6),
        padding: btnPad,
        textStyle: btnLabel,
        shape: plank(c.line2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.accent,
        textStyle: T.body(14, w: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: c.surface2,
      side: BorderSide(color: c.line2),
      labelStyle: T.body(12.5, w: FontWeight.w600, color: c.ink),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    dividerTheme: DividerThemeData(color: c.line2.o(.7), thickness: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.accent,
      linearTrackColor: c.line,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.ink,
        borderRadius: BorderRadius.circular(5),
      ),
      textStyle: T.body(12.5, color: c.bg),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      contentTextStyle: T.body(14, w: FontWeight.w500, color: c.bg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  );
}

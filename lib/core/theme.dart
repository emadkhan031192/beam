import 'package:flutter/material.dart';

/// Exact design tokens for Beam.
abstract final class BeamColors {
  static const bg = Color(0xFF0A0A0C);
  static const surface = Color(0xFF111216);
  static const surfaceAlt = Color(0xFF14151A);
  static const line = Color(0xFF1C1E24);
  static const lineStrong = Color(0xFF23252B);
  static const text = Color(0xFFF2F0EA);
  static const secondary = Color(0xFF8A8D98);
  static const secondaryAlt = Color(0xFFA3A6B0);
  static const amber = Color(0xFFFFB547);
  static const amberHot = Color(0xFFFFE3A6);
  static const onAmber = Color(0xFF2A1B02); // dark ink on amber
  static const screenLight = Color(0xFFFFE9C2);
  static const danger = Color(0xFFD8321E);
  static const sheet = Color(0xFF0C0D10); // near-black bottom sheet
}

abstract final class BeamType {
  static const wordmark = TextStyle(
    fontFamily: 'BricolageGrotesque',
    fontWeight: FontWeight.w800,
    fontSize: 22,
    height: 1.1,
    color: BeamColors.text,
  );

  static TextStyle screenTitle(BuildContext context) {
    // Respect the system font scale: scale the 24–28 range with the scaler.
    final scaler = MediaQuery.textScalerOf(context);
    final size = scaler.scale(26).clamp(24.0, 40.0);
    return TextStyle(
      fontFamily: 'BricolageGrotesque',
      fontWeight: FontWeight.w800,
      fontSize: size,
      height: 1.15,
      color: BeamColors.text,
    );
  }

  static const sectionLabel = TextStyle(
    fontFamily: 'MartianMono',
    fontWeight: FontWeight.w500,
    fontSize: 10,
    letterSpacing: 1.6, // 0.16em of 10px
    color: BeamColors.secondary,
  );

  static const mono = TextStyle(
    fontFamily: 'MartianMono',
    fontWeight: FontWeight.w500,
    color: BeamColors.text,
  );

  static const body = TextStyle(
    fontFamily: 'BricolageGrotesque',
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 1.45,
    color: BeamColors.secondaryAlt,
  );

  static const bodyStrong = TextStyle(
    fontFamily: 'BricolageGrotesque',
    fontWeight: FontWeight.w500,
    fontSize: 15,
    height: 1.45,
    color: BeamColors.text,
  );
}

ThemeData beamTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: BeamColors.bg,
    fontFamily: 'BricolageGrotesque',
    colorScheme: const ColorScheme.dark(
      primary: BeamColors.amber,
      onPrimary: BeamColors.onAmber,
      surface: BeamColors.surface,
      onSurface: BeamColors.text,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: BeamColors.amber,
      inactiveTrackColor: BeamColors.lineStrong,
      thumbColor: BeamColors.amber,
      overlayColor: Color(0x22FFB547),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? BeamColors.onAmber
            : BeamColors.secondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? BeamColors.amber
            : BeamColors.lineStrong,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: BeamColors.surfaceAlt,
      contentTextStyle: TextStyle(
        fontFamily: 'BricolageGrotesque',
        color: BeamColors.text,
        fontSize: 14,
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Section label: Martian Mono 10px uppercase with 0.16em tracking,
/// followed by a 1px hairline.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(text.toUpperCase(), style: BeamType.sectionLabel),
        const SizedBox(height: 8),
        const Divider(height: 1, thickness: 1, color: BeamColors.line),
      ],
    );
  }
}

/// Pressable wrapper: scales to 0.95 over 80ms while pressed.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.onTap,
    required this.child,
    this.semanticLabel,
  });

  final VoidCallback? onTap;
  final Widget child;
  final String? semanticLabel;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Widget child = AnimatedScale(
      scale: _pressed ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 80),
      child: widget.child,
    );
    if (widget.semanticLabel != null) {
      child = Semantics(
        label: widget.semanticLabel,
        button: true,
        child: child,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: child,
    );
  }
}

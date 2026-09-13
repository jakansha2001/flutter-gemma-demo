import 'package:flutter/material.dart';

/// Design tokens for the demo.
///
/// Dark, high-contrast and projector-friendly: a conference screen washes out
/// mid-tones, so the palette stays at the extremes and leans on the accent
/// ramp for hierarchy rather than on subtle greys.
abstract final class AppColors {
  // Surfaces — a near-black base with layered elevation.
  static const bg = Color(0xFF08080C);
  static const bgElevated = Color(0xFF101018);
  static const surface = Color(0xFF16161F);
  static const surfaceHigh = Color(0xFF1E1E2A);
  static const border = Color(0x14FFFFFF);
  static const borderStrong = Color(0x26FFFFFF);

  // Brand ramp — kept from the v1 talk deck.
  static const accent = Color(0xFFFF5722);
  static const accentBright = Color(0xFFFF8A50);
  static const accentDeep = Color(0xFFE64100);

  // Feature colors. Each demo gets one so the UI reads at a glance.
  static const vision = Color(0xFF42A5F5);
  static const thinking = Color(0xFF9B7BFF);
  static const tool = Color(0xFF00D9A3);
  static const voice = Color(0xFFFF4E8A);

  // Text.
  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFFA0A0AE);
  static const textTertiary = Color(0xFF62626F);

  // Status.
  static const success = Color(0xFF4ADE80);
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFFF5E5E);

  static const accentGradient = LinearGradient(
    colors: [accentBright, accent, accentDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Soft radial wash behind the hero, so the flat black has some depth.
  static const heroGlow = RadialGradient(
    center: Alignment(-0.7, -0.9),
    radius: 1.3,
    colors: [Color(0x33FF5722), Color(0x00FF5722)],
  );
}

abstract final class AppText {
  static const hero = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    height: 1.05,
    letterSpacing: -1.5,
  );
  static const title = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.15,
    letterSpacing: -0.5,
  );
  static const heading = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );
  static const body = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 15,
    height: 1.5,
  );
  static const bodySmall = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 13,
    height: 1.45,
  );
  static const caption = TextStyle(
    color: AppColors.textTertiary,
    fontSize: 12,
    height: 1.4,
  );
  static const label = TextStyle(
    color: AppColors.accent,
    fontSize: 11,
    letterSpacing: 1.8,
    fontWeight: FontWeight.w800,
  );
  static const mono = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['Menlo', 'Courier New'],
    fontSize: 12.5,
    height: 1.5,
    color: AppColors.textSecondary,
  );
}

abstract final class AppRadius {
  static const card = 14.0;
  static const button = 12.0;
  static const pill = 999.0;
  static const bubble = 18.0;
}

/// App-wide spacing scale, so padding is never a magic number.
abstract final class Gap {
  static const xs = SizedBox(height: 4);
  static const sm = SizedBox(height: 8);
  static const md = SizedBox(height: 16);
  static const lg = SizedBox(height: 24);
  static const xl = SizedBox(height: 36);

  static const wSm = SizedBox(width: 8);
  static const wMd = SizedBox(width: 14);
}

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    ).copyWith(surface: AppColors.bg, error: AppColors.danger),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: AppText.heading,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: const TextStyle(color: AppColors.textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
    ),
  );
}

/// Primary CTA with the brand gradient. Falls back to a flat disabled state.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.accentGradient : null,
          color: enabled ? null : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.button),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: Color(0x4DFF5722),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(AppRadius.button),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else if (icon != null)
                    Icon(icon, size: 18, color: Colors.white),
                  if (busy || icon != null) Gap.wSm,
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small uppercase chip used for feature tags and status.
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Standard elevated container — one place to change card styling.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: child,
    );
  }
}

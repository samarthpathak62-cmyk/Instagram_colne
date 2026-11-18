import 'package:flutter/material.dart';
import 'package:instagram_clone/core/constants/app_constants.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';

class VeyroMark extends StatelessWidget {
  final double size;
  final bool decorative;

  const VeyroMark({super.key, this.size = 46, this.decorative = true});

  @override
  Widget build(BuildContext context) => Image.asset(
        AppConstants.appLogoPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: decorative,
        semanticLabel: decorative ? null : 'Veyro orbital V',
      );
}

class VeyroWordmark extends StatelessWidget {
  final double size;
  final bool showMark;
  final Color? color;

  const VeyroWordmark(
      {super.key, this.size = 25, this.showMark = true, this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showMark) ...[
            VeyroMark(size: size * 1.65),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                AppConstants.appName,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: VeyroTheme.font,
                  color: color ?? context.veyroColors.onSurface,
                  fontSize: size,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -size * .048,
                ),
              ),
            ),
          ),
        ],
      );
}

class VeyroTagline extends StatelessWidget {
  final Color? color;

  const VeyroTagline({super.key, this.color});

  @override
  Widget build(BuildContext context) => Text(
        AppConstants.tagline,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color ?? context.veyroColors.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.1,
          height: 1.6,
        ),
      );
}

/// Decorative artwork; UI text is always rendered separately for accessibility.
class VeyroOrbitArtwork extends StatelessWidget {
  final AlignmentGeometry alignment;
  final BoxFit fit;

  const VeyroOrbitArtwork(
      {super.key, this.alignment = Alignment.center, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) => Image.asset(
        AppConstants.orbitArtworkPath,
        fit: fit,
        alignment: alignment,
        excludeFromSemantics: true,
      );
}

class VeyroOrbitRing extends StatelessWidget {
  final Widget child;
  final bool glowing;
  final Color? surface;

  const VeyroOrbitRing(
      {super.key, required this.child, this.glowing = true, this.surface});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: glowing ? null : context.veyroColors.outlineVariant,
          gradient: glowing ? VeyroTheme.orbit : null,
        ),
        child: Padding(
            padding: const EdgeInsets.all(2.5),
            child: DecoratedBox(
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: surface ?? context.veyroColors.surface),
              child: Padding(padding: const EdgeInsets.all(3), child: child),
            )),
      );
}

class VeyroEyebrow extends StatelessWidget {
  final String label;
  final Color? color;

  const VeyroEyebrow(this.label, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: context.veyroText.labelSmall?.copyWith(
            color: color ?? context.veyroColors.primary,
            letterSpacing: 1.65,
            fontWeight: FontWeight.w800),
      );
}

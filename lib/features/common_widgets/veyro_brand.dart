import 'dart:math' as math;

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

/// The dark violet atmosphere of the icon, used for feature moments rather
/// than behind every piece of content.
class VeyroAtmosphere extends StatelessWidget {
  final Widget child;
  final bool rings;

  const VeyroAtmosphere({super.key, required this.child, this.rings = false});

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1B1030),
                    VeyroTheme.ink,
                    Color(0xFF150D26)
                  ],
                  stops: [0, .52, 1],
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(.86, -.92),
                  radius: 1.1,
                  colors: [Color(0x65622BBC), Color(0x00532799)],
                ),
              ),
            ),
          ),
          if (rings)
            const Positioned.fill(
              child: CustomPaint(painter: _OrbitPainter()),
            ),
          child,
        ],
      );
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width * .53, size.height * .35);
    final radius = math.min(size.width, size.height) * .42;
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(-.44);
    for (var i = 0; i < 3; i++) {
      final scale = 1 + i * .16;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 2 * scale,
          height: radius * .94 * scale,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = VeyroTheme.lavender.withValues(alpha: .19 - i * .047),
      );
    }
    canvas.drawCircle(
      Offset(-radius * .91, -radius * .24),
      3,
      Paint()..color = VeyroTheme.lavender.withValues(alpha: .75),
    );
    canvas.drawCircle(
      Offset(radius * .91, radius * .23),
      2.4,
      Paint()..color = VeyroTheme.lavender.withValues(alpha: .57),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) => false;
}

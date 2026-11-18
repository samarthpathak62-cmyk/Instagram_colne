import 'package:flutter/material.dart';

/// Brand artwork for community surfaces. Text always sits above the contrast
/// layer, never inside the artwork.
class VeyroCommunityCover extends StatelessWidget {
  final Widget child;

  const VeyroCommunityCover({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xFF201230),
              child: Image.asset(
                'assets/brand/veyro_community.webp',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [
                    Color(0xFF171022),
                    Color(0xDD171022),
                    Color(0x47171022)
                  ],
                  stops: [0, .45, 1],
                ),
              ),
            ),
          ),
          child,
        ],
      );
}

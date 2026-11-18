import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/groups/domain/veyro_group.dart';

extension GroupCategoryVisual on GroupCategory {
  IconData get icon => switch (this) {
        GroupCategory.general => Icons.groups_outlined,
        GroupCategory.creative => Icons.camera_alt_outlined,
        GroupCategory.local => Icons.location_on_outlined,
        GroupCategory.gaming => Icons.sports_esports_outlined,
        GroupCategory.learning => Icons.lightbulb_outline_rounded,
      };

  Color get accent => switch (this) {
        GroupCategory.general => const Color(0xFF2B63CB),
        GroupCategory.creative => const Color(0xFF9B4978),
        GroupCategory.local => const Color(0xFF27836B),
        GroupCategory.gaming => const Color(0xFF556BC5),
        GroupCategory.learning => const Color(0xFFAD6724),
      };
}

String groupMemberCount(int count) =>
    '$count ${count == 1 ? 'member' : 'members'}';

class GroupArtwork extends StatelessWidget {
  final GroupCategory category;
  final double height;

  const GroupArtwork({super.key, required this.category, this.height = 86});

  @override
  Widget build(BuildContext context) {
    final colors = context.veyroColors;
    final dark = colors.brightness == Brightness.dark;
    final base = Color.alphaBlend(
        category.accent.withValues(alpha: dark ? .24 : .08),
        colors.surfaceContainerLow);
    final strong = Color.alphaBlend(
        category.accent.withValues(alpha: dark ? .62 : .23),
        colors.surfaceContainerLow);
    final ink = dark ? colors.onSurface : category.accent;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Stack(fit: StackFit.expand, children: [
          DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [base, strong],
          ))),
          CustomPaint(painter: _OrbitLines(category.accent)),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.outlineVariant),
                  color: colors.surfaceContainerLow,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(category.icon, color: ink, size: 24),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _OrbitLines extends CustomPainter {
  final Color accent;
  const _OrbitLines(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width * .86, size.height * .5);
    canvas.rotate(-math.pi / 6);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (var i = 0; i < 6; i++) {
      paint.color = accent.withValues(alpha: .29 - i * .035);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset.zero,
              width: 105 + 29.0 * i,
              height: 39 + 15.0 * i),
          paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbitLines oldDelegate) =>
      oldDelegate.accent != accent;
}

class GroupStatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  const GroupStatusCard(
      {super.key,
      required this.icon,
      required this.title,
      required this.description,
      this.action});

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: context.veyroColors.primaryContainer,
              foregroundColor: context.veyroColors.onPrimaryContainer,
              child: Icon(icon),
            ),
            const SizedBox(height: 13),
            Text(title,
                style: context.veyroText.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 5),
            Text(description,
                style: context.veyroText.bodySmall,
                textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 14), action!],
          ]),
        ),
      );
}

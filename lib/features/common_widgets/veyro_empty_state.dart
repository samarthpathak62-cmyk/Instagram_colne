import 'package:flutter/material.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';

/// Compact enough to work inside a feed or a sheet as well as a full screen.
class VeyroEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  const VeyroEmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.description,
      this.action});

  @override
  Widget build(BuildContext context) {
    final colors = context.veyroColors;
    return Center(
        child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 365),
      child: SingleChildScrollView(
          primary: false,
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VeyroOrbitRing(
                      glowing: false,
                      child: CircleAvatar(
                          radius: 23,
                          backgroundColor: colors.primaryContainer,
                          foregroundColor: colors.onPrimaryContainer,
                          child: Icon(icon, size: 23))),
                  const SizedBox(height: 13),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: context.veyroText.titleMedium),
                  const SizedBox(height: 5),
                  Text(description,
                      textAlign: TextAlign.center,
                      style: context.veyroText.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant, height: 1.45)),
                  if (action != null) ...[const SizedBox(height: 13), action!],
                ],
              ))),
    ));
  }
}

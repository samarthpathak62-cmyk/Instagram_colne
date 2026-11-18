import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final VoidCallback? onTap;

  const UserAvatar({super.key, this.imageUrl, this.radius = 20, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = Icon(Icons.person_outline_rounded,
        color: colors.onPrimaryContainer, size: radius * 1.2);
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: colors.primaryContainer,
      child: imageUrl?.isNotEmpty == true
          ? ClipOval(
              child: Image.network(imageUrl!,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => fallback))
          : fallback,
    );
    return onTap == null ? avatar : InkResponse(onTap: onTap, child: avatar);
  }
}

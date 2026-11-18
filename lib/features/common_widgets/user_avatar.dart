import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? name;
  final VoidCallback? onTap;

  const UserAvatar(
      {super.key, this.imageUrl, this.radius = 20, this.onTap, this.name});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = name?.trim().replaceFirst(RegExp(r'^@'), '') ?? '';
    final fallback = label.isEmpty
        ? Icon(Icons.person_outline_rounded,
            color: colors.onPrimaryContainer, size: radius * 1.2)
        : Text(String.fromCharCode(label.runes.first).toUpperCase(),
            style: TextStyle(
                color: colors.onPrimaryContainer,
                fontSize: radius * .88,
                fontWeight: FontWeight.w800));
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

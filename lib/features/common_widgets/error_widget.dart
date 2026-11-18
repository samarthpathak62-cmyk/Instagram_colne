import 'package:flutter/material.dart';
import 'package:instagram_clone/features/common_widgets/veyro_empty_state.dart';

class CustomErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const CustomErrorWidget({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => VeyroEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Something went wrong',
        description: message,
        action: onRetry == null
            ? null
            : FilledButton.tonal(
                onPressed: onRetry, child: const Text('Retry')),
      );
}

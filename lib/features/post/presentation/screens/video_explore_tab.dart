import 'package:flutter/material.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/common_widgets/app_bar.dart';

class VideoExploreTab extends StatelessWidget {
  const VideoExploreTab({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const CustomAppBar(title: 'Reels', showDefaultActions: false),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: context.veyroColors.primaryContainer,
                  foregroundColor: context.veyroColors.onPrimaryContainer,
                  child: const Icon(Icons.video_collection_outlined, size: 30),
                ),
                const SizedBox(height: 18),
                Text('Reels', style: context.veyroText.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'Reels aren’t available yet.',
                  textAlign: TextAlign.center,
                  style: context.veyroText.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
}

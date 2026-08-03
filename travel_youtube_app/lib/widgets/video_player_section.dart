import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Renders an embedded YouTube player for the given controller.
/// The controller is owned by the parent screen so that place-card
/// timestamp taps can call `controller.seekTo(...)` directly.
class VideoPlayerSection extends StatelessWidget {
  final YoutubePlayerController controller;

  const VideoPlayerSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: YoutubePlayer(controller: controller),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../widgets/video_player_section.dart';

/// Handle for controlling an already-built player instance (seeking to a
/// timestamp from a place-card tap, disposing when the screen closes).
abstract class VideoPlayerHandle {
  void seekTo(int seconds);
  void dispose();
}

/// A built player: the widget to render plus the handle used to control it.
class VideoPlayerInstance {
  final Widget widget;
  final VideoPlayerHandle handle;

  const VideoPlayerInstance({required this.widget, required this.handle});
}

/// Abstraction over "build an embedded video player". Screens depend on
/// this, not on `youtube_player_iframe` (WebView-backed) directly — so
/// player code stays out of UI code, and widget tests can substitute a
/// fake instead of loading a real native WebView.
abstract class VideoPlayerRepository {
  const VideoPlayerRepository();

  VideoPlayerInstance createPlayer(String? videoId);
}

class _YoutubeIframeHandle extends VideoPlayerHandle {
  final YoutubePlayerController _controller;

  _YoutubeIframeHandle(this._controller);

  @override
  void seekTo(int seconds) => _controller.seekTo(seconds: seconds.toDouble(), allowSeekAhead: true);

  @override
  void dispose() => _controller.close();
}

/// Production implementation, backed by `youtube_player_iframe`.
class YoutubeIframePlayerRepository extends VideoPlayerRepository {
  const YoutubeIframePlayerRepository();

  @override
  VideoPlayerInstance createPlayer(String? videoId) {
    final controller = YoutubePlayerController(
      params: const YoutubePlayerParams(showControls: true, showFullscreenButton: true),
    );
    if (videoId != null) {
      controller.loadVideoById(videoId: videoId);
    }

    return VideoPlayerInstance(
      widget: VideoPlayerSection(controller: controller),
      handle: _YoutubeIframeHandle(controller),
    );
  }
}

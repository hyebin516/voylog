import 'package:flutter/material.dart';
import 'package:travel_youtube_app/repositories/video_player_repository.dart';

/// Stand-in for the real WebView-backed YouTube player in widget tests.
/// Renders a plain Text widget instead, and records seek/dispose calls so
/// tests can assert on them.
class FakeVideoPlayerRepository extends VideoPlayerRepository {
  final List<int> seekCalls = [];
  bool disposed = false;

  @override
  VideoPlayerInstance createPlayer(String? videoId) {
    return VideoPlayerInstance(
      widget: Text('fake-player video=$videoId'),
      handle: _FakeVideoPlayerHandle(this),
    );
  }
}

class _FakeVideoPlayerHandle extends VideoPlayerHandle {
  final FakeVideoPlayerRepository _repository;

  _FakeVideoPlayerHandle(this._repository);

  @override
  void seekTo(int seconds) => _repository.seekCalls.add(seconds);

  @override
  void dispose() => _repository.disposed = true;
}

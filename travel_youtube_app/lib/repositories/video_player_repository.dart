import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../core/config/env.dart';
import '../core/theme/app_theme.dart';
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

// youtube_player_iframe's own command methods (cueVideoById, seekTo, ...)
// all wait on the player's JS-side `onReady` event reaching Dart before
// running anything -- and on this WebView that event never arrives, even
// though the underlying player works fine and responds instantly to direct
// JS once it exists (confirmed via DevTools: calling `player.cueVideoById`
// on the raw page loads the video immediately). So the initial cue and
// seekTo bypass the package's bridge and run JS directly on the
// controller's public `webViewController`.
void _runOnPlayer(YoutubePlayerController controller, String statement) {
  // Swallows failures from the platform WebView already being torn down --
  // e.g. a queued command firing after the user navigated away.
  unawaited(
    controller.webViewController
        .runJavaScript(
          "if (typeof player !== 'undefined' && player) { $statement }",
        )
        .catchError((_) {}),
  );
}

enum _PlayerLoad { loading, ready, failed, unplayable }

const Duration _pollInterval = Duration(milliseconds: 500);

// With no network the iframe API script never loads; after this long the
// user is told so instead of staring at a blank box.
const Duration _failAfter = Duration(seconds: 10);

// How often the API script is re-requested while it's missing, so playback
// recovers on its own once the connection comes back.
const Duration _retryScriptEvery = Duration(seconds: 8);

// A cue issued before the iframe finished its handshake can be dropped
// silently, so it's re-sent at this spacing until the player reports the
// video as loaded.
const Duration _recueEvery = Duration(seconds: 2);

const Duration _apiCallbackGrace = Duration(seconds: 3);

// While the video is up, how often to check that it still is.
const Duration _healthCheckEvery = Duration(seconds: 2);

/// Drives the page until the requested video is actually cued, observed via
/// DevTools on a real device to fail in two different ways:
///
/// 1. `https://www.youtube.com/iframe_api` never loads (no network, or a
///    dropped request), so `YT` and `player` never exist. The previous
///    fixed-length poll gave up silently and left a blank white box.
/// 2. `player` exists but the one-shot cue was lost, leaving the iframe on
///    `youtube.com/embed/?` with no video id -- also a blank box.
///
/// Instead of trusting that a command landed, this keeps checking what the
/// player reports (`getVideoUrl`) and re-sends whatever is missing.
///
/// It keeps checking after the video is up, too. The WebView can reload the
/// player page later (seen on device: a fresh page with an empty player, 27s
/// after the video had loaded), and a loader that stopped at the first
/// success left that as a blank white box with no spinner and no error --
/// and "영상에서 보기" then seeked a player that had no video in it.
class _PlayerLoader {
  final YoutubePlayerController controller;
  final String videoId;
  final ValueNotifier<_PlayerLoad> status = ValueNotifier(_PlayerLoad.loading);

  Timer? _timer;
  final Stopwatch _sinceStart = Stopwatch();
  DateTime _lastScriptRetry = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastCue = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _apiLoadedSince;
  DateTime _lastHealthCheck = DateTime.fromMillisecondsSinceEpoch(0);
  bool _checking = false;
  bool _disposed = false;

  /// A seek asked for before the player could take it (still loading, or
  /// reloaded and empty). Applied as soon as the player is there.
  int? _pendingSeek;

  _PlayerLoader(this.controller, this.videoId);

  void start() {
    _sinceStart
      ..reset()
      ..start();
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => _tick());
  }

  /// Manual "다시 시도": re-request the API script right away.
  void retry() {
    if (_disposed) return;
    status.value = _PlayerLoad.loading;
    _reloadApiScript();
    start();
  }

  /// Jumps to [seconds], loading the video there first if the player lost it.
  void seekTo(int seconds) {
    if (_disposed) return;
    _pendingSeek = seconds;
    unawaited(_tick());
  }

  /// The video was up and is gone again (the page reloaded): back to the
  /// loading overlay, with a fresh clock so the "can't load" message isn't
  /// shown the instant this happens.
  void _lostVideo() {
    if (status.value != _PlayerLoad.ready) return;
    status.value = _PlayerLoad.loading;
    _sinceStart
      ..reset()
      ..start();
    _lastCue = DateTime.fromMillisecondsSinceEpoch(0);
    _apiLoadedSince = null;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    status.dispose();
  }

  Future<void> _tick() async {
    if (_checking) return;
    final now = DateTime.now();
    // Once the video is up there is nothing to do but notice if it goes
    // away again, which doesn't need the loading-time 500ms pace.
    if (status.value == _PlayerLoad.ready &&
        _pendingSeek == null &&
        now.difference(_lastHealthCheck) < _healthCheckEvery) {
      return;
    }
    _lastHealthCheck = now;
    _checking = true;
    try {
      final state = await _readState();
      // The screen may have closed while the check was in flight.
      if (_disposed) return;

      if (state.startsWith('error:')) {
        // YouTube itself refused this video in an embed (the owner disabled
        // embedding, it's private/removed, ...). Re-cueing can't fix that.
        status.value = _PlayerLoad.unplayable;
        _timer?.cancel();
        return;
      }

      // Only an empty player or a missing API means the video is gone. A
      // known video at -1 while it was up is just playback starting --
      // treating that as lost would re-cue and stop what the user started.
      if (state == 'ready' || state == 'api-loaded' || state == 'no-api') {
        _lostVideo();
      }
      if (state == 'starting' && status.value == _PlayerLoad.ready) return;

      switch (state) {
        case 'cued':
          status.value = _PlayerLoad.ready;
          final seek = _pendingSeek;
          if (seek != null) {
            _pendingSeek = null;
            _runOnPlayer(controller, 'player.seekTo($seek, true);');
          }
        case 'ready':
        case 'starting':
          final seek = _pendingSeek;
          if (seek != null) {
            // The player is there but empty: load the video straight at the
            // requested moment instead of cueing it and seeking afterwards.
            _pendingSeek = null;
            _lastCue = now;
            _runOnPlayer(
              controller,
              'player.loadVideoById(${jsonEncode({'videoId': videoId, 'startSeconds': seek})});',
            );
          } else if (now.difference(_lastCue) >= _recueEvery) {
            _lastCue = now;
            _runOnPlayer(
              controller,
              'player.cueVideoById(${jsonEncode({'videoId': videoId})});',
            );
          }
        case 'api-loaded':
          // The API finished but the page's ready callback hasn't built the
          // player (it can miss the load event on a retried script). Give
          // the page's own callback a moment first, so this never builds a
          // second player alongside it.
          _apiLoadedSince ??= now;
          if (now.difference(_apiLoadedSince!) >= _apiCallbackGrace) {
            _apiLoadedSince = null;
            _runJs(
              "if (typeof onYouTubeIframeAPIReady === 'function' && (typeof player === 'undefined' || !player)) { onYouTubeIframeAPIReady(); }",
            );
          }
        case 'no-api':
          if (_sinceStart.elapsed >= _failAfter) {
            status.value = _PlayerLoad.failed;
          }
          if (now.difference(_lastScriptRetry) >= _retryScriptEvery) {
            _lastScriptRetry = now;
            _reloadApiScript();
          }
        default:
          // The WebView isn't up yet -- keep waiting.
          break;
      }
    } finally {
      _checking = false;
    }
  }

  Future<String> _readState() async {
    final id = jsonEncode(videoId);
    try {
      final result = await controller.webViewController
          .runJavaScriptReturningResult('''
(function () {
  if (typeof YT === 'undefined' || !YT.Player) return 'no-api';
  if (typeof player === 'undefined' || !player) return 'api-loaded';
  if (typeof player.cueVideoById !== 'function') return 'loading';
  if (!window.__voylogErrorHooked && typeof player.addEventListener === 'function') {
    player.addEventListener('onError', function (e) { window.__voylogError = e.data; });
    window.__voylogErrorHooked = true;
  }
  if (window.__voylogError !== undefined) return 'error:' + window.__voylogError;
  // getVideoUrl() alone is not proof: it echoes the requested id even when
  // the iframe never loaded it (observed at state -1 behind a blank player).
  // The player state is what reflects a video actually loaded -- but -1 is
  // also the brief "unstarted" step every play goes through, so a known
  // video at -1 is reported separately ('starting') rather than as missing.
  var st = typeof player.getPlayerState === 'function' ? player.getPlayerState() : -1;
  var url = typeof player.getVideoUrl === 'function' ? (player.getVideoUrl() || '') : '';
  if (url.indexOf($id) < 0) return 'ready';
  return st !== -1 ? 'cued' : 'starting';
})()
''');
      return result.toString().replaceAll('"', '');
    } catch (_) {
      return 'webview-not-ready';
    }
  }

  void _reloadApiScript() {
    _runJs(
      "(function(){var s=document.createElement('script');s.src='https://www.youtube.com/iframe_api';document.head.appendChild(s);})();",
    );
  }

  void _runJs(String js) {
    unawaited(
      controller.webViewController.runJavaScript(js).catchError((_) {}),
    );
  }
}

class _YoutubeIframeHandle extends VideoPlayerHandle {
  final YoutubePlayerController _controller;
  final _PlayerLoader? _loader;

  _YoutubeIframeHandle(this._controller, this._loader);

  @override
  void seekTo(int seconds) {
    final loader = _loader;
    if (loader != null) {
      loader.seekTo(seconds);
    } else {
      _runOnPlayer(_controller, 'player.seekTo($seconds, true);');
    }
  }

  @override
  void dispose() {
    _loader?.dispose();
    _controller.close();
  }
}

/// The player with a status layer on top: a spinner while the video is
/// being loaded, and an explanation plus retry when YouTube can't be reached
/// -- never a silent blank box. The WebView stays underneath the whole time
/// so loading carries on behind the overlay.
class _PlayerWithStatus extends StatelessWidget {
  final YoutubePlayerController controller;
  final _PlayerLoader loader;

  const _PlayerWithStatus({required this.controller, required this.loader});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        VideoPlayerSection(controller: controller),
        ValueListenableBuilder<_PlayerLoad>(
          valueListenable: loader.status,
          builder: (context, status, _) {
            if (status == _PlayerLoad.ready) return const SizedBox.shrink();
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ColoredBox(
                color: AppColors.ink,
                child: Center(
                  child: status == _PlayerLoad.unplayable
                      ? const Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.block_rounded,
                                color: Colors.white70,
                                size: 28,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '이 영상은 앱에서 재생할 수 없어요',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '영상 제공자가 외부 재생을 막아 두었어요. 장소 정보는 그대로 볼 수 있어요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      : status == _PlayerLoad.loading
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.wifi_off_rounded,
                                color: Colors.white70,
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '영상을 불러오지 못했어요',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '인터넷 연결을 확인해 주세요. 연결되면 자동으로 다시 불러와요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton(
                                onPressed: loader.retry,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white54),
                                  minimumSize: const Size(0, 34),
                                ),
                                child: const Text('다시 시도'),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Production implementation, backed by `youtube_player_iframe`.
class YoutubeIframePlayerRepository extends VideoPlayerRepository {
  const YoutubeIframePlayerRepository();

  @override
  VideoPlayerInstance createPlayer(String? videoId) {
    // `privacyEnhancedMode: false` keeps the embed on youtube.com instead of
    // youtube-nocookie.com -- confirmed via chrome://inspect that on this
    // WebView, a cued video on youtube-nocookie.com never actually starts
    // playing (playVideo() succeeds with no error but state stays stuck at
    // unstarted/cued), while the identical sequence on youtube.com plays
    // normally.
    //
    // `origin` becomes the player page's origin and the Referer YouTube
    // sees. The package's default (https://www.youtube.com) is now rejected
    // with error 152-4 -- verified on device: the identical embed errored
    // from a youtube.com page and played from an ordinary https origin.
    final params = YoutubePlayerParams(
      showControls: true,
      showFullscreenButton: true,
      privacyEnhancedMode: false,
      origin: Env.youtubeEmbedOrigin,
      // The package forces English captions on by default, which stacked an
      // English CC line over the Korean subtitles these vlogs already burn
      // into the picture. Viewers can still turn captions on from controls.
      enableCaption: false,
    );
    final controller = YoutubePlayerController(params: params);

    if (videoId == null) {
      return VideoPlayerInstance(
        widget: VideoPlayerSection(controller: controller),
        handle: _YoutubeIframeHandle(controller, null),
      );
    }

    final loader = _PlayerLoader(controller, videoId)..start();
    return VideoPlayerInstance(
      widget: _PlayerWithStatus(controller: controller, loader: loader),
      handle: _YoutubeIframeHandle(controller, loader),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/map_view_types.dart';
import '../models/place_model.dart';
import '../providers/video_provider.dart';
import '../repositories/map_repository.dart';
import '../repositories/video_player_repository.dart';
import '../routes/app_routes.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/place_card.dart';

class VideoAnalysisScreen extends StatefulWidget {
  /// Defaults to the real native Kakao map. Widget tests inject
  /// `FakeMapRepository()` instead.
  final MapRepository mapRepository;

  /// Defaults to the real WebView-backed YouTube player. Widget tests
  /// inject `FakeVideoPlayerRepository()` instead.
  final VideoPlayerRepository videoPlayerRepository;

  const VideoAnalysisScreen({
    super.key,
    this.mapRepository = const KakaoMapRepository(),
    this.videoPlayerRepository = const YoutubeIframePlayerRepository(),
  });

  @override
  State<VideoAnalysisScreen> createState() => _VideoAnalysisScreenState();
}

class _VideoAnalysisScreenState extends State<VideoAnalysisScreen> {
  late final VideoPlayerInstance _player;

  @override
  void initState() {
    super.initState();
    final videoId = context.read<VideoProvider>().currentVideo?.videoId;
    _player = widget.videoPlayerRepository.createPlayer(videoId);
  }

  @override
  void dispose() {
    _player.handle.dispose();
    super.dispose();
  }

  void _seekTo(int seconds) {
    _player.handle.seekTo(seconds);
  }

  Future<void> _openDetail(PlaceModel place) async {
    final seekTo = await Navigator.pushNamed(context, AppRoutes.placeDetail, arguments: place);
    if (seekTo is int) {
      _seekTo(seekTo);
    }
  }

  void _showOnMap(PlaceModel place) {
    if (!place.hasCoordinates) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(place.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: widget.mapRepository.buildMap(
                    initialLatitude: place.latitude!,
                    initialLongitude: place.longitude!,
                    markers: [
                      MapMarkerData(
                        id: place.placeId,
                        title: place.name,
                        latitude: place.latitude!,
                        longitude: place.longitude!,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final video = context.watch<VideoProvider>().currentVideo;

    if (video == null) {
      return const Scaffold(body: LoadingIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: Text(video.title ?? '영상 분석 결과')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _player.widget,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '장소 목록',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: video.places.isEmpty
                ? const Center(child: Text('추출된 장소가 없습니다.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    itemCount: video.places.length,
                    itemBuilder: (context, index) {
                      final place = video.places[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: PlaceCard(
                          placeId: place.placeId,
                          name: place.name,
                          address: place.address,
                          timestampSec: place.timestampSec,
                          onTap: () => _openDetail(place),
                          onTimestampTap: place.timestampSec != null ? () => _seekTo(place.timestampSec!) : null,
                          onMapTap: place.hasCoordinates ? () => _showOnMap(place) : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

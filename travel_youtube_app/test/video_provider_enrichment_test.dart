import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/place_model.dart';
import 'package:travel_youtube_app/models/video_model.dart';
import 'package:travel_youtube_app/providers/video_provider.dart';
import 'package:travel_youtube_app/repositories/video_repository.dart';

const _place = PlaceModel(
  placeId: 'p1',
  name: '경포 해수역장',
  timestampSec: 10,
  latitude: null,
  longitude: null,
  address: null,
  source: 'transcript',
  confidence: 0.8,
);

const _correctedPlace = PlaceModel(
  placeId: 'p1',
  name: '경포 해수욕장',
  timestampSec: 10,
  latitude: 37.8,
  longitude: 128.9,
  address: '강원 강릉시',
  source: 'transcript',
  confidence: 0.8,
);

VideoModel _video({required bool pending, required List<PlaceModel> places}) => VideoModel(
      videoId: 'v1',
      youtubeVideoId: 'v1',
      title: '강릉 브이로그',
      isCached: false,
      enrichmentPending: pending,
      places: places,
    );

/// 첫 호출은 보강 진행 중, 이후는 끝난 결과를 돌려준다.
class _FakeRepository extends VideoRepository {
  _FakeRepository(this.afterEnrichment);

  final VideoModel afterEnrichment;
  int calls = 0;

  @override
  Future<VideoModel> analyze(String youtubeUrl) async {
    calls++;
    if (calls == 1) return _video(pending: true, places: const [_place]);
    return afterEnrichment;
  }
}

void main() {
  group('보강이 끝나면', () {
    test('장소 개수가 그대로여도 "더 찾고 있어요"가 사라진다', () async {
      // 전에는 개수가 늘었을 때만 화면 데이터를 바꿔서, 개수가 같으면
      // 옛 데이터의 enrichmentPending=true가 남아 배너가 영원히 돌았다.
      final repository = _FakeRepository(
        _video(pending: false, places: const [_place]),
      );
      final provider = VideoProvider(repository: repository);

      await provider.analyze('https://youtu.be/v1');
      expect(provider.currentVideo!.enrichmentPending, isTrue);

      await Future<void>.delayed(const Duration(seconds: 6));

      expect(provider.currentVideo!.enrichmentPending, isFalse);
      provider.dispose();
    });

    test('개수가 같아도 고쳐진 이름과 좌표가 반영된다', () async {
      // 보강은 장소를 더 찾기만 하는 게 아니라 이미 있는 장소의 이름을
      // 고치고 좌표를 채우기도 한다. 그 개선이 버려지면 안 된다.
      final repository = _FakeRepository(
        _video(pending: false, places: const [_correctedPlace]),
      );
      final provider = VideoProvider(repository: repository);

      await provider.analyze('https://youtu.be/v1');
      await Future<void>.delayed(const Duration(seconds: 6));

      expect(provider.currentVideo!.places.single.name, '경포 해수욕장');
      expect(provider.currentVideo!.places.single.latitude, isNotNull);
      provider.dispose();
    });
  });
}

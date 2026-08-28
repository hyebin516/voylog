import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/place_summary_model.dart';
import 'package:travel_youtube_app/providers/place_summary_provider.dart';
import 'package:travel_youtube_app/repositories/place_summary_repository.dart';
import 'package:travel_youtube_app/utils/view_state.dart';

const PlaceSummaryModel _unavailableResult = PlaceSummaryModel(available: false, pros: null, cons: null, sourceCount: 1);
const PlaceSummaryModel _availableResult = PlaceSummaryModel(
  available: true,
  pros: '뷰가 좋다는 평이 많아요.',
  cons: '웨이팅이 길다는 평이 많아요.',
  sourceCount: 2,
);

class FakePlaceSummaryRepository extends PlaceSummaryRepository {
  PlaceSummaryModel? resultToReturn;
  ApiException? error;
  String? lastRequestedPlaceId;

  @override
  Future<PlaceSummaryModel> getSummary(String placeId) async {
    lastRequestedPlaceId = placeId;
    if (error != null) throw error!;
    return resultToReturn ?? _unavailableResult;
  }
}

void main() {
  late FakePlaceSummaryRepository repository;
  late PlaceSummaryProvider provider;

  setUp(() {
    repository = FakePlaceSummaryRepository();
    provider = PlaceSummaryProvider(repository: repository);
  });

  test('starts idle with no summary', () {
    expect(provider.state, ViewState.idle);
    expect(provider.summary, isNull);
  });

  test('load transitions idle -> loading -> success and stores the summary', () async {
    repository.resultToReturn = _availableResult;

    final future = provider.load('p1');
    expect(provider.isLoading, isTrue);
    await future;

    expect(provider.state, ViewState.success);
    expect(provider.summary, _availableResult);
    expect(repository.lastRequestedPlaceId, 'p1');
  });

  test('load stores an unavailable result distinctly from an error', () async {
    repository.resultToReturn = _unavailableResult;

    await provider.load('p1');

    expect(provider.state, ViewState.success);
    expect(provider.summary?.available, isFalse);
  });

  test('load transitions to error and stores a friendly message on failure', () async {
    repository.error = const ApiException(code: 'NETWORK_ERROR', message: 'boom');

    await provider.load('p1');

    expect(provider.state, ViewState.error);
    expect(provider.errorMessage, '네트워크 연결을 확인해 주세요.');
  });
}

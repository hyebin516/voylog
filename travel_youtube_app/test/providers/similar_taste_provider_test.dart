import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/similar_taste_recommendation_model.dart';
import 'package:travel_youtube_app/providers/similar_taste_provider.dart';
import 'package:travel_youtube_app/repositories/similar_taste_repository.dart';
import 'package:travel_youtube_app/utils/view_state.dart';

const SimilarTasteResultModel _noPreferenceResult = SimilarTasteResultModel(hasPreference: false, recommendations: []);
const SimilarTasteResultModel _emptyResult = SimilarTasteResultModel(hasPreference: true, recommendations: []);

class FakeSimilarTasteRepository extends SimilarTasteRepository {
  SimilarTasteResultModel? resultToReturn;
  ApiException? error;

  @override
  Future<SimilarTasteResultModel> getRecommendations({int? limit}) async {
    if (error != null) throw error!;
    return resultToReturn ?? _emptyResult;
  }
}

void main() {
  late FakeSimilarTasteRepository repository;
  late SimilarTasteProvider provider;

  setUp(() {
    repository = FakeSimilarTasteRepository();
    provider = SimilarTasteProvider(repository: repository);
  });

  test('starts idle with no result', () {
    expect(provider.state, ViewState.idle);
    expect(provider.result, isNull);
  });

  test('load transitions idle -> loading -> success and stores the result', () async {
    repository.resultToReturn = _emptyResult;

    final future = provider.load();
    expect(provider.isLoading, isTrue);
    await future;

    expect(provider.state, ViewState.success);
    expect(provider.result, _emptyResult);
  });

  test('load stores hasPreference: false distinctly from an empty recommendation list', () async {
    repository.resultToReturn = _noPreferenceResult;

    await provider.load();

    expect(provider.result?.hasPreference, isFalse);
  });

  test('load transitions to error and stores a friendly message on failure', () async {
    repository.error = const ApiException(code: 'NETWORK_ERROR', message: 'boom');

    await provider.load();

    expect(provider.state, ViewState.error);
    expect(provider.errorMessage, '네트워크 연결을 확인해 주세요.');
  });
}

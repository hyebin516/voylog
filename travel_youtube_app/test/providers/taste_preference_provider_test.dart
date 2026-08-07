import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/taste_preference_model.dart';
import 'package:travel_youtube_app/providers/taste_preference_provider.dart';
import 'package:travel_youtube_app/repositories/taste_preference_repository.dart';
import 'package:travel_youtube_app/utils/view_state.dart';

class FakeTastePreferenceRepository extends TastePreferenceRepository {
  TastePreferenceModel preferencesToReturn = const TastePreferenceModel(tags: []);
  ApiException? getError;
  ApiException? setError;
  ApiException? clearError;
  List<String>? lastSetTags;
  int clearCallCount = 0;

  @override
  Future<TastePreferenceModel> getPreferences() async {
    if (getError != null) throw getError!;
    return preferencesToReturn;
  }

  @override
  Future<TastePreferenceModel> setPreferences(List<String> tags) async {
    lastSetTags = tags;
    if (setError != null) throw setError!;
    return TastePreferenceModel(tags: tags);
  }

  @override
  Future<void> clearPreferences() async {
    clearCallCount++;
    if (clearError != null) throw clearError!;
  }
}

void main() {
  late FakeTastePreferenceRepository repository;
  late TastePreferenceProvider provider;

  setUp(() {
    repository = FakeTastePreferenceRepository();
    provider = TastePreferenceProvider(repository: repository);
  });

  test('starts idle with no selected tags', () {
    expect(provider.state, ViewState.idle);
    expect(provider.selectedTags, isEmpty);
  });

  test('toggleTag adds and then removes a tag', () {
    provider.toggleTag('소금빵');
    expect(provider.selectedTags, {'소금빵'});

    provider.toggleTag('소금빵');
    expect(provider.selectedTags, isEmpty);
  });

  group('loadPreferences', () {
    test('prefills selectedTags from the saved preferences', () async {
      repository.preferencesToReturn = const TastePreferenceModel(tags: ['소금빵', '오션뷰']);

      await provider.loadPreferences();

      expect(provider.state, ViewState.success);
      expect(provider.selectedTags, {'소금빵', '오션뷰'});
    });

    test('transitions to error on failure', () async {
      repository.getError = const ApiException(code: 'NETWORK_ERROR', message: 'boom');

      await provider.loadPreferences();

      expect(provider.state, ViewState.error);
    });
  });

  group('save', () {
    test('does nothing and returns false when no tags are selected', () async {
      final result = await provider.save();

      expect(result, isFalse);
      expect(repository.lastSetTags, isNull);
    });

    test('saves the selected tags and returns true on success', () async {
      provider.toggleTag('소금빵');

      final result = await provider.save();

      expect(result, isTrue);
      expect(repository.lastSetTags, ['소금빵']);
      expect(provider.selectedTags, {'소금빵'});
    });

    test('returns false and sets an error message on failure', () async {
      provider.toggleTag('소금빵');
      repository.setError = const ApiException(code: 'INTERNAL_ERROR', message: 'boom');

      final result = await provider.save();

      expect(result, isFalse);
      expect(provider.errorMessage, isNotNull);
    });
  });

  group('reset', () {
    test('clears the selected tags and returns true on success', () async {
      provider.toggleTag('소금빵');

      final result = await provider.reset();

      expect(result, isTrue);
      expect(repository.clearCallCount, 1);
      expect(provider.selectedTags, isEmpty);
    });

    test('returns false and sets an error message on failure', () async {
      repository.clearError = const ApiException(code: 'INTERNAL_ERROR', message: 'boom');

      final result = await provider.reset();

      expect(result, isFalse);
      expect(provider.errorMessage, isNotNull);
    });
  });
}

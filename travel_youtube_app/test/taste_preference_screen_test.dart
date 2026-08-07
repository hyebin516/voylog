import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/taste_preference_model.dart';
import 'package:travel_youtube_app/providers/taste_preference_provider.dart';
import 'package:travel_youtube_app/repositories/taste_preference_repository.dart';
import 'package:travel_youtube_app/screens/taste_preference_screen.dart';

class FakeTastePreferenceRepository extends TastePreferenceRepository {
  TastePreferenceModel preferencesToReturn = const TastePreferenceModel(tags: []);
  ApiException? getError;
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
    return TastePreferenceModel(tags: tags);
  }

  @override
  Future<void> clearPreferences() async {
    clearCallCount++;
  }
}

Widget _wrap(TastePreferenceProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(home: const TastePreferenceScreen()),
  );
}

void main() {
  testWidgets('save button is disabled until a tag is selected', (tester) async {
    final repository = FakeTastePreferenceRepository();
    await tester.pumpWidget(_wrap(TastePreferenceProvider(repository: repository)));
    await tester.pumpAndSettle();

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('prefills previously saved tags as selected', (tester) async {
    final repository = FakeTastePreferenceRepository()
      ..preferencesToReturn = const TastePreferenceModel(tags: ['소금빵']);
    await tester.pumpWidget(_wrap(TastePreferenceProvider(repository: repository)));
    await tester.pumpAndSettle();

    final chip = tester.widget<FilterChip>(find.byKey(const Key('tastePreference_소금빵')));
    expect(chip.selected, isTrue);
  });

  testWidgets('selecting a tag and saving calls the repository', (tester) async {
    final repository = FakeTastePreferenceRepository();
    await tester.pumpWidget(_wrap(TastePreferenceProvider(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tastePreference_소금빵')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('tastePreferenceSaveButton')));
    await tester.pumpAndSettle();

    expect(repository.lastSetTags, ['소금빵']);
    expect(find.text('취향이 저장되었습니다.'), findsOneWidget);
  });

  testWidgets('tapping 초기화 clears saved preferences', (tester) async {
    final repository = FakeTastePreferenceRepository()
      ..preferencesToReturn = const TastePreferenceModel(tags: ['소금빵']);
    await tester.pumpWidget(_wrap(TastePreferenceProvider(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tastePreferenceResetButton')));
    await tester.pumpAndSettle();

    expect(repository.clearCallCount, 1);
    expect(find.text('취향 설정이 초기화되었습니다.'), findsOneWidget);
  });

  testWidgets('shows an error view when loading fails', (tester) async {
    final repository = FakeTastePreferenceRepository()
      ..getError = const ApiException(code: 'NETWORK_ERROR', message: 'boom');
    await tester.pumpWidget(_wrap(TastePreferenceProvider(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('네트워크 연결을 확인해 주세요.'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/providers/recommendation_wizard_provider.dart';

void main() {
  late RecommendationWizardProvider provider;

  setUp(() {
    provider = RecommendationWizardProvider();
  });

  test('starts with no selections and cannot proceed', () {
    expect(provider.selectedRegions, isEmpty);
    expect(provider.selectedThemes, isEmpty);
    expect(provider.selectedDuration, isNull);
    expect(provider.canProceedFromRegions, isFalse);
    expect(provider.canProceedFromThemes, isFalse);
    expect(provider.canSearch, isFalse);
  });

  test('toggleRegion adds and then removes a region', () {
    provider.toggleRegion('제주');
    expect(provider.selectedRegions, {'제주'});
    expect(provider.canProceedFromRegions, isTrue);

    provider.toggleRegion('제주');
    expect(provider.selectedRegions, isEmpty);
    expect(provider.canProceedFromRegions, isFalse);
  });

  test('toggleTheme adds and then removes a theme', () {
    provider.toggleTheme('자연');
    expect(provider.selectedThemes, {'자연'});
    expect(provider.canProceedFromThemes, isTrue);

    provider.toggleTheme('자연');
    expect(provider.selectedThemes, isEmpty);
    expect(provider.canProceedFromThemes, isFalse);
  });

  test('selectDuration replaces the previous selection', () {
    provider.selectDuration('당일치기');
    expect(provider.selectedDuration, '당일치기');

    provider.selectDuration('1박2일');
    expect(provider.selectedDuration, '1박2일');
  });

  test('canSearch is true only once a region, theme, and duration are all chosen', () {
    provider.toggleRegion('제주');
    expect(provider.canSearch, isFalse);

    provider.toggleTheme('자연');
    expect(provider.canSearch, isFalse);

    provider.selectDuration('1박2일');
    expect(provider.canSearch, isTrue);
  });

  test('reset clears all selections', () {
    provider.toggleRegion('제주');
    provider.toggleTheme('자연');
    provider.selectDuration('1박2일');

    provider.reset();

    expect(provider.selectedRegions, isEmpty);
    expect(provider.selectedThemes, isEmpty);
    expect(provider.selectedDuration, isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/taste_preference_model.dart';

void main() {
  test('TastePreferenceModel.fromJson parses the tag list', () {
    final model = TastePreferenceModel.fromJson({
      'tags': ['소금빵', '오션뷰'],
    });

    expect(model.tags, ['소금빵', '오션뷰']);
  });

  test('an empty tags array parses to an empty list', () {
    final model = TastePreferenceModel.fromJson({'tags': []});

    expect(model.tags, isEmpty);
  });
}

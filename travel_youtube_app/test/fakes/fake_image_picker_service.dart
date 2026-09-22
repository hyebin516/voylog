import 'package:travel_youtube_app/services/image_picker_service.dart';

/// Stands in for the gallery under `flutter test`: the real picker needs a
/// platform channel and a user tapping a photo.
class FakeImagePickerService implements ImagePickerService {
  FakeImagePickerService({this.pathToReturn = '/tmp/picked.jpg'});

  /// null reproduces the user closing the gallery without choosing.
  String? pathToReturn;
  int pickCount = 0;

  @override
  Future<String?> pickFromGallery() async {
    pickCount += 1;
    return pathToReturn;
  }
}

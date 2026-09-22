import 'package:image_picker/image_picker.dart';

/// Picking a photo from the device's gallery, behind an interface so
/// `flutter test` never reaches for the platform channel (CLAUDE.md's
/// real/fake rule for native features).
abstract class ImagePickerService {
  /// The chosen file's path, or null when the user backed out.
  Future<String?> pickFromGallery();
}

class GalleryImagePickerService implements ImagePickerService {
  const GalleryImagePickerService();

  /// Avatars are never shown larger than 64dp, so the full-resolution
  /// original would be megabytes uploaded to draw a thumbnail. The picker
  /// downscales on the device, which also keeps the upload inside the
  /// backend's 5MB ceiling without asking the user to crop anything.
  static const double _maxDimension = 512;
  static const int _quality = 85;

  @override
  Future<String?> pickFromGallery() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: _quality,
    );
    return picked?.path;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/bookmark_folder_model.dart';

void main() {
  test('BookmarkFolderModel.fromJson parses a folder with its bookmark count', () {
    final folder = BookmarkFolderModel.fromJson({
      'folderId': 'f1',
      'name': '제주 맛집',
      'bookmarkCount': 3,
      'createdAt': '2026-01-01T00:00:00.000Z',
    });

    expect(folder.folderId, 'f1');
    expect(folder.name, '제주 맛집');
    expect(folder.bookmarkCount, 3);
    expect(folder.createdAt, DateTime.parse('2026-01-01T00:00:00.000Z'));
  });
}

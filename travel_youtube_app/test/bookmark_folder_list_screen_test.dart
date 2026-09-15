import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/bookmark_folder_model.dart';
import 'package:travel_youtube_app/providers/bookmark_folder_provider.dart';
import 'package:travel_youtube_app/repositories/bookmark_folder_repository.dart';
import 'package:travel_youtube_app/screens/bookmark_folder_list_screen.dart';

class FakeBookmarkFolderRepository extends BookmarkFolderRepository {
  List<BookmarkFolderModel> foldersToReturn = [];
  BookmarkFolderModel? createdFolder;
  ApiException? deleteError;
  final List<String> deleteCalls = [];

  @override
  Future<List<BookmarkFolderModel>> listFolders() async => foldersToReturn;

  @override
  Future<BookmarkFolderModel> createFolder(String name) async => createdFolder!;

  @override
  Future<void> deleteFolder(String folderId) async {
    deleteCalls.add(folderId);
    if (deleteError != null) throw deleteError!;
  }
}

Widget _wrap(BookmarkFolderProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      home: const BookmarkFolderListScreen(),
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('folder detail'))),
    ),
  );
}

void main() {
  testWidgets('shows an empty state when there are no folders yet', (tester) async {
    final repository = FakeBookmarkFolderRepository();
    await tester.pumpWidget(_wrap(BookmarkFolderProvider(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('아직 만든 폴더가 없습니다.'), findsOneWidget);
  });

  testWidgets('lists folders with their saved bookmark count', (tester) async {
    final repository = FakeBookmarkFolderRepository()
      ..foldersToReturn = [
        BookmarkFolderModel(folderId: 'f1', name: '제주 맛집', bookmarkCount: 3, createdAt: DateTime(2026, 1, 1)),
      ];
    await tester.pumpWidget(_wrap(BookmarkFolderProvider(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('제주 맛집'), findsOneWidget);
    expect(find.text('장소 3곳'), findsOneWidget);
  });

  testWidgets('creating a folder navigates to its detail screen', (tester) async {
    final repository = FakeBookmarkFolderRepository()
      ..createdFolder = BookmarkFolderModel(folderId: 'f1', name: '부산 여행', bookmarkCount: 0, createdAt: DateTime(2026, 1, 1));
    await tester.pumpWidget(_wrap(BookmarkFolderProvider(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '부산 여행');
    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();

    expect(find.text('folder detail'), findsOneWidget);
  });

  testWidgets('deleting a folder removes it from the list after confirmation', (tester) async {
    final repository = FakeBookmarkFolderRepository()
      ..foldersToReturn = [
        BookmarkFolderModel(folderId: 'f1', name: '제주 맛집', bookmarkCount: 1, createdAt: DateTime(2026, 1, 1)),
      ];
    await tester.pumpWidget(_wrap(BookmarkFolderProvider(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, ['f1']);
    expect(find.text('제주 맛집'), findsNothing);
    expect(find.text('아직 만든 폴더가 없습니다.'), findsOneWidget);
  });
}

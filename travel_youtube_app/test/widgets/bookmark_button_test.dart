import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/bookmark_model.dart';
import 'package:travel_youtube_app/models/bookmark_folder_model.dart';
import 'package:travel_youtube_app/providers/bookmark_folder_provider.dart';
import 'package:travel_youtube_app/providers/bookmark_provider.dart';
import 'package:travel_youtube_app/repositories/bookmark_folder_repository.dart';
import 'package:travel_youtube_app/repositories/bookmark_repository.dart';
import 'package:travel_youtube_app/utils/place_id.dart';
import 'package:travel_youtube_app/widgets/bookmark_button.dart';

const _realPlaceId = 'b4e01fd9-a17c-4fec-bee6-24184eff96ee';

class FakeBookmarkRepository extends BookmarkRepository {
  ApiException? addError;
  final List<BookmarkModel> stored = [];

  @override
  Future<List<BookmarkModel>> listBookmarks() async => stored;

  @override
  Future<String> addBookmark(String placeId) async {
    if (addError != null) throw addError!;
    final bookmark = BookmarkModel(
      bookmarkId: 'b1',
      placeId: placeId,
      videoId: null,
      name: '카페 산시',
      address: null,
      latitude: null,
      longitude: null,
      timestampSec: null,
      source: 'kakao_local',
      confidence: 1,
      bookmarkedAt: DateTime(2026, 9, 29),
    );
    stored.add(bookmark);
    return bookmark.bookmarkId;
  }

  @override
  Future<void> removeBookmark(String bookmarkId) async {
    stored.removeWhere((b) => b.bookmarkId == bookmarkId);
  }
}

class FakeBookmarkFolderRepository extends BookmarkFolderRepository {
  @override
  Future<List<BookmarkFolderModel>> listFolders() async => [];
}

Widget _wrap(BookmarkProvider provider, String placeId) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        ChangeNotifierProvider(
          create: (_) => BookmarkFolderProvider(repository: FakeBookmarkFolderRepository()),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(body: BookmarkButton(placeId: placeId)),
      ),
    );

void main() {
  group('isBookmarkablePlaceId', () {
    test('a places row id is bookmarkable', () {
      expect(isBookmarkablePlaceId(_realPlaceId), isTrue);
    });

    test('a Kakao search id is not -- the API rejects a non-UUID outright', () {
      expect(isBookmarkablePlaceId('kakao:25661344'), isFalse);
      expect(isBookmarkablePlaceId(null), isFalse);
      expect(isBookmarkablePlaceId(''), isFalse);
    });
  });

  testWidgets('shows no button for a place that cannot be bookmarked', (
    tester,
  ) async {
    // It used to render and fail silently: the icon never filled in and no
    // message appeared, which read as the app being broken.
    final provider = BookmarkProvider(repository: FakeBookmarkRepository());

    await tester.pumpWidget(_wrap(provider, 'kakao:25661344'));

    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('shows the button for a real place', (tester) async {
    final provider = BookmarkProvider(repository: FakeBookmarkRepository());

    await tester.pumpWidget(_wrap(provider, _realPlaceId));

    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
  });

  testWidgets('tells the user when saving the bookmark failed', (tester) async {
    final repository = FakeBookmarkRepository()
      ..addError = const ApiException(
        code: 'INVALID_REQUEST',
        message: 'A valid placeId is required',
      );
    final provider = BookmarkProvider(repository: repository);

    await tester.pumpWidget(_wrap(provider, _realPlaceId));
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('saving a place opens the folder sheet', (tester) async {
    final provider = BookmarkProvider(repository: FakeBookmarkRepository());

    await tester.pumpWidget(_wrap(provider, _realPlaceId));
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(find.text('북마크에 저장'), findsOneWidget);
  });

  testWidgets('tapping a place already saved opens the sheet rather than unsaving it', (tester) async {
    // The design's icon is "open the save sheet", not a toggle. A second tap
    // used to remove the bookmark on the spot with nothing shown, which left
    // no way back to its folders.
    final repository = FakeBookmarkRepository();
    final provider = BookmarkProvider(repository: repository);

    await tester.pumpWidget(_wrap(provider, _realPlaceId));
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장하기'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bookmark_rounded));
    await tester.pumpAndSettle();

    expect(find.text('북마크에 저장'), findsOneWidget);
    expect(provider.isBookmarked(_realPlaceId), isTrue);
  });

  testWidgets('the sheet can unsave the bookmark outright', (tester) async {
    final provider = BookmarkProvider(repository: FakeBookmarkRepository());

    await tester.pumpWidget(_wrap(provider, _realPlaceId));
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('북마크 해제'));
    await tester.pumpAndSettle();

    expect(provider.isBookmarked(_realPlaceId), isFalse);
    expect(find.text('북마크에 저장'), findsNothing);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
  });
}

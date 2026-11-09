import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/bookmark_folder_model.dart';
import '../models/bookmark_model.dart';
import '../models/place_search_result_model.dart';
import '../repositories/bookmark_folder_repository.dart';
import '../utils/view_state.dart';

class BookmarkFolderProvider extends ChangeNotifier {
  final BookmarkFolderRepository _repository;

  BookmarkFolderProvider({BookmarkFolderRepository? repository})
      : _repository = repository ?? BookmarkFolderRepository();

  ViewState _state = ViewState.idle;
  List<BookmarkFolderModel> _folders = [];
  String? _errorMessage;

  ViewState get state => _state;
  List<BookmarkFolderModel> get folders => _folders;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ViewState.loading;

  ViewState _detailState = ViewState.idle;
  List<BookmarkModel> _folderBookmarks = [];
  Set<String> _folderBookmarkIds = {};
  String? _detailErrorMessage;

  ViewState get detailState => _detailState;
  List<BookmarkModel> get folderBookmarks => _folderBookmarks;
  bool isInCurrentFolder(String bookmarkId) => _folderBookmarkIds.contains(bookmarkId);
  String? get detailErrorMessage => _detailErrorMessage;
  bool get isDetailLoading => _detailState == ViewState.loading;

  Future<void> loadFolders() async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _folders = await _repository.listFolders();
      _state = ViewState.success;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  Future<BookmarkFolderModel?> createFolder(String name) async {
    try {
      final folder = await _repository.createFolder(name);
      _folders = [folder, ..._folders];
      notifyListeners();
      return folder;
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteFolder(String folderId) async {
    try {
      await _repository.deleteFolder(folderId);
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return false;
    }

    _folders = _folders.where((f) => f.folderId != folderId).toList();
    notifyListeners();
    return true;
  }

  Future<void> loadFolderBookmarks(String folderId) async {
    _detailState = ViewState.loading;
    _detailErrorMessage = null;
    notifyListeners();

    try {
      _folderBookmarks = await _repository.listBookmarksInFolder(folderId);
      _folderBookmarkIds = _folderBookmarks.map((b) => b.bookmarkId).toSet();
      _detailState = ViewState.success;
    } on ApiException catch (e) {
      _detailState = ViewState.error;
      _detailErrorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  /// 폴더 목록이 들고 있는 장소 개수를 방금 바뀐 폴더만 맞춰 둔다.
  ///
  /// 목록의 `bookmarkCount`는 `loadFolders()`가 한 번 받아온 값이라, 폴더에
  /// 장소를 담아도 목록 쪽 숫자는 그대로였다. 여행 날짜를 만들 때 고르는
  /// 폴더 화면에서 방금 4곳을 담은 폴더가 "장소 0곳"으로 보였고, 앱을 다시
  /// 띄워야 제 숫자가 나왔다. 개수는 방금 받아온 `_folderBookmarks`의
  /// 길이와 같으므로 서버를 다시 부르지 않는다.
  void _syncFolderCount(String folderId) {
    _folders = [
      for (final folder in _folders)
        folder.folderId == folderId
            ? folder.copyWith(bookmarkCount: _folderBookmarks.length)
            : folder,
    ];
  }

  Future<void> toggleBookmarkInFolder(String folderId, String bookmarkId) async {
    final wasIn = _folderBookmarkIds.contains(bookmarkId);

    try {
      if (wasIn) {
        await _repository.removeBookmarkFromFolder(folderId, bookmarkId);
      } else {
        await _repository.addBookmarkToFolder(folderId, bookmarkId);
      }
      await loadFolderBookmarks(folderId);
      _syncFolderCount(folderId);
      notifyListeners();
    } on ApiException catch (e) {
      _detailErrorMessage = e.friendlyMessage;
      notifyListeners();
    }
  }

  // ── 폴더에 넣을 장소 검색 ──────────────────────────────────
  // 검색창은 하나지만 결과는 내 북마크와 카카오 양쪽에서 온다.
  ViewState _searchState = ViewState.idle;
  List<PlaceSearchResultModel> _searchResults = [];
  String? _searchErrorMessage;

  ViewState get searchState => _searchState;
  List<PlaceSearchResultModel> get searchResults => _searchResults;
  String? get searchErrorMessage => _searchErrorMessage;

  Future<void> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      clearSearch();
      return;
    }

    _searchState = ViewState.loading;
    _searchErrorMessage = null;
    notifyListeners();

    try {
      _searchResults = await _repository.searchPlaces(trimmed);
      _searchState = ViewState.success;
    } on ApiException catch (e) {
      _searchState = ViewState.error;
      _searchErrorMessage = e.friendlyMessage;
    }
    notifyListeners();
  }

  void clearSearch() {
    _searchResults = [];
    _searchState = ViewState.idle;
    _searchErrorMessage = null;
    notifyListeners();
  }

  /// 검색 결과 한 줄을 폴더에 넣는다. 이미 북마크한 장소면 그 북마크를
  /// 토글하고, 카카오에서 온 장소면 서버가 적재까지 해준다.
  Future<bool> addSearchResultToFolder(String folderId, PlaceSearchResultModel place) async {
    try {
      if (place.isBookmarked) {
        await _repository.addBookmarkToFolder(folderId, place.bookmarkId!);
      } else {
        await _repository.addSearchedPlaceToFolder(folderId, place);
      }
      await loadFolderBookmarks(folderId);
      _syncFolderCount(folderId);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _searchErrorMessage = e.friendlyMessage;
      notifyListeners();
      return false;
    }
  }

  void clearFolderDetail() {
    _folderBookmarks = [];
    _folderBookmarkIds = {};
    _detailState = ViewState.idle;
    notifyListeners();
  }
}

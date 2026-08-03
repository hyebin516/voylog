import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/bookmark_model.dart';
import '../repositories/bookmark_repository.dart';
import '../utils/view_state.dart';

class BookmarkProvider extends ChangeNotifier {
  final BookmarkRepository _repository;

  BookmarkProvider({BookmarkRepository? repository}) : _repository = repository ?? BookmarkRepository();

  ViewState _state = ViewState.idle;
  List<BookmarkModel> _bookmarks = [];
  String? _errorMessage;

  ViewState get state => _state;
  List<BookmarkModel> get bookmarks => _bookmarks;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ViewState.loading;

  bool isBookmarked(String placeId) => _bookmarks.any((b) => b.placeId == placeId);

  Future<void> loadBookmarks() async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _bookmarks = await _repository.listBookmarks();
      _state = ViewState.success;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  Future<void> toggleBookmark(String placeId) async {
    final matches = _bookmarks.where((b) => b.placeId == placeId);
    final existing = matches.isEmpty ? null : matches.first;

    try {
      if (existing != null) {
        await _repository.removeBookmark(existing.bookmarkId);
        _bookmarks = _bookmarks.where((b) => b.placeId != placeId).toList();
      } else {
        await _repository.addBookmark(placeId);
        await loadBookmarks();
        return;
      }
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }
}

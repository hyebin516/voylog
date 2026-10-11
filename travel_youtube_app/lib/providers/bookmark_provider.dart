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

  /// Drops a message a screen has already shown, so the next bookmark
  /// isn't judged by the previous one's failure.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// The bookmark row for [placeId], which the folder sheet needs to address
  /// it. Null when the place is not bookmarked.
  String? bookmarkIdFor(String placeId) {
    final matches = _bookmarks.where((b) => b.placeId == placeId);
    return matches.isEmpty ? null : matches.first.bookmarkId;
  }

  Future<void> addBookmark(String placeId) async {
    _errorMessage = null;

    try {
      await _repository.addBookmark(placeId);
      // Refetched rather than appended locally: the sheet that opens next
      // needs the server's bookmarkId.
      await loadBookmarks();
      return;
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  /// Drops the bookmark itself, not just its folder membership. This is the
  /// only way back out for a place saved from a card, so it lives in the
  /// folder sheet rather than behind a second tap on the bookmark icon --
  /// that tap now opens the sheet, as the design has it.
  Future<void> removeBookmark(String placeId) async {
    final existing = bookmarkIdFor(placeId);
    if (existing == null) return;
    _errorMessage = null;

    try {
      await _repository.removeBookmark(existing);
      _bookmarks = _bookmarks.where((b) => b.placeId != placeId).toList();
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  Future<void> toggleBookmark(String placeId) async {
    if (bookmarkIdFor(placeId) != null) return removeBookmark(placeId);
    return addBookmark(placeId);
  }
}

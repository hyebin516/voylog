import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/bookmark_model.dart';
import '../models/place_search_result_model.dart';
import '../providers/bookmark_folder_provider.dart';
import '../providers/bookmark_provider.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';

/// 폴더에 장소를 넣는 화면.
///
/// 검색창은 하나이고, 입력하면 내가 북마크해 둔 장소와 카카오 검색 결과가
/// 함께 나온다. 전에는 북마크 목록에서만 고를 수 있어서, 가고 싶은 곳이
/// 생겨도 어느 영상에선가 그 장소가 먼저 추출돼 있어야 담을 수 있었다.
///
/// 검색어가 비어 있을 때는 예전처럼 북마크 전체를 체크박스로 보여준다 --
/// 담아둔 곳을 여러 개 한꺼번에 넣는 건 그 편이 빠르다.
class BookmarkFolderPickerScreen extends StatefulWidget {
  final String folderId;

  const BookmarkFolderPickerScreen({super.key, required this.folderId});

  @override
  State<BookmarkFolderPickerScreen> createState() => _BookmarkFolderPickerScreenState();
}

class _BookmarkFolderPickerScreenState extends State<BookmarkFolderPickerScreen> {
  final TextEditingController _queryController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookmarkProvider>().loadBookmarks();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  /// 글자를 칠 때마다 보내면 카카오 호출이 낭비된다. 손이 멈춘 뒤에 한 번만
  /// 보낸다.
  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      context.read<BookmarkFolderProvider>().searchPlaces(value);
    });
  }

  Future<void> _add(PlaceSearchResultModel place) async {
    final provider = context.read<BookmarkFolderProvider>();
    final added = await provider.addSearchResultToFolder(widget.folderId, place);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added ? '${place.name}을(를) 폴더에 담았어요' : provider.searchErrorMessage ?? '추가하지 못했습니다.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folderProvider = context.watch<BookmarkFolderProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.surfaceTint2, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('폴더에 추가', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: TextField(
                key: const Key('folderPlaceSearchField'),
                controller: _queryController,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '장소 이름으로 검색 (예: 전주 한옥마을)',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _queryController.clear();
                            _onQueryChanged('');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: _query.trim().isEmpty
                  ? _BookmarkChecklist(folderId: widget.folderId)
                  : _SearchResults(
                      state: folderProvider.searchState,
                      results: folderProvider.searchResults,
                      errorMessage: folderProvider.searchErrorMessage,
                      isInFolder: (place) =>
                          place.bookmarkId != null && folderProvider.isInCurrentFolder(place.bookmarkId!),
                      onAdd: _add,
                      onRetry: () => folderProvider.searchPlaces(_query),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 검색어가 없을 때: 담아둔 장소를 체크박스로 여러 개 넣는다.
class _BookmarkChecklist extends StatelessWidget {
  const _BookmarkChecklist({required this.folderId});

  final String folderId;

  @override
  Widget build(BuildContext context) {
    final bookmarkProvider = context.watch<BookmarkProvider>();
    final folderProvider = context.watch<BookmarkFolderProvider>();

    if (bookmarkProvider.isLoading && bookmarkProvider.bookmarks.isEmpty) {
      return const LoadingIndicator();
    }
    if (bookmarkProvider.state == ViewState.error && bookmarkProvider.bookmarks.isEmpty) {
      return ErrorView(
        message: bookmarkProvider.errorMessage ?? '북마크를 불러오지 못했습니다.',
        onRetry: () => bookmarkProvider.loadBookmarks(),
      );
    }
    if (bookmarkProvider.bookmarks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            '담아둔 장소가 없어요.\n위에서 장소 이름을 검색해 바로 추가할 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, height: 1.5),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
      itemCount: bookmarkProvider.bookmarks.length,
      separatorBuilder: (context, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final BookmarkModel bookmark = bookmarkProvider.bookmarks[index];
        // Material, not a colored Container: the tile paints its tap ripple
        // on the nearest Material, which a colored Container would hide.
        return Material(
          color: AppColors.surfaceTint1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.dividerStrong, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: CheckboxListTile(
            title: Text(bookmark.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
            subtitle: bookmark.address != null
                ? Text(bookmark.address!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))
                : null,
            value: folderProvider.isInCurrentFolder(bookmark.bookmarkId),
            onChanged: (_) => folderProvider.toggleBookmarkInFolder(folderId, bookmark.bookmarkId),
            activeColor: AppColors.primary,
          ),
        );
      },
    );
  }
}

/// 검색어가 있을 때: 내 북마크와 카카오 결과를 한 목록으로.
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.state,
    required this.results,
    required this.errorMessage,
    required this.isInFolder,
    required this.onAdd,
    required this.onRetry,
  });

  final ViewState state;
  final List<PlaceSearchResultModel> results;
  final String? errorMessage;
  final bool Function(PlaceSearchResultModel) isInFolder;
  final Future<void> Function(PlaceSearchResultModel) onAdd;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state == ViewState.loading) return const LoadingIndicator();
    if (state == ViewState.error) {
      return ErrorView(message: errorMessage ?? '검색하지 못했습니다.', onRetry: onRetry);
    }
    if (state == ViewState.success && results.isEmpty) {
      return const Center(
        child: Text('검색 결과가 없어요.', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
      itemCount: results.length,
      separatorBuilder: (context, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final place = results[index];
        final already = isInFolder(place);

        return Material(
          color: AppColors.surfaceTint1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.dividerStrong, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            title: Row(
              children: [
                Flexible(
                  child: Text(place.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                ),
                if (place.isBookmarked) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTint2,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('담아둔 곳',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primaryStrong)),
                  ),
                ],
              ],
            ),
            subtitle: place.address != null
                ? Text(place.address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted))
                : null,
            trailing: already
                ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                : const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryStrong, size: 22),
            onTap: already ? null : () => onAdd(place),
          ),
        );
      },
    );
  }
}

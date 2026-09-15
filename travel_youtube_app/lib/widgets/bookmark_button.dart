import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/bookmark_provider.dart';
import 'bookmark_folder_sheet.dart';

class BookmarkButton extends StatelessWidget {
  final String placeId;

  /// Fired only when the place transitions from not-bookmarked to
  /// bookmarked (not on un-bookmarking) -- used by screens that also want
  /// to record a "bookmark" behavior signal (phase 5 personalization).
  final VoidCallback? onBookmarked;

  const BookmarkButton({super.key, required this.placeId, this.onBookmarked});

  @override
  Widget build(BuildContext context) {
    return Consumer<BookmarkProvider>(
      builder: (context, bookmarkProvider, _) {
        final bookmarked = bookmarkProvider.isBookmarked(placeId);
        final colorScheme = Theme.of(context).colorScheme;

        return IconButton(
          onPressed: () async {
            final wasBookmarked = bookmarked;
            await bookmarkProvider.toggleBookmark(placeId);
            if (wasBookmarked) return;

            onBookmarked?.call();
            if (!context.mounted) return;
            final matches = bookmarkProvider.bookmarks.where((b) => b.placeId == placeId);
            if (matches.isEmpty) return;
            await showBookmarkFolderSheet(context, bookmarkId: matches.first.bookmarkId);
          },
          icon: Icon(
            bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: bookmarked ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          tooltip: bookmarked ? '북마크 해제' : '북마크',
        );
      },
    );
  }
}

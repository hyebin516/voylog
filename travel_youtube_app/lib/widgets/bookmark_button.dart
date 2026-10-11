import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/bookmark_provider.dart';
import '../utils/place_id.dart';
import 'bookmark_folder_sheet.dart';

class BookmarkButton extends StatelessWidget {
  final String placeId;

  /// Fired only when the place transitions from not-bookmarked to
  /// bookmarked (not on un-bookmarking) -- used by screens that also want
  /// to record a "bookmark" behavior signal (phase 5 personalization).
  final VoidCallback? onBookmarked;

  const BookmarkButton({super.key, required this.placeId, this.onBookmarked, this.compact = false});

  /// A smaller icon and tap area, for rows that sit next to another icon.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // A place with no row in `places` can never be bookmarked -- the API
    // rejects the id outright. The button used to render anyway and fail
    // silently, so tapping it looked like the app was broken.
    if (!isBookmarkablePlaceId(placeId)) return const SizedBox.shrink();

    return Consumer<BookmarkProvider>(
      builder: (context, bookmarkProvider, _) {
        final bookmarked = bookmarkProvider.isBookmarked(placeId);
        final colorScheme = Theme.of(context).colorScheme;

        return IconButton(
          onPressed: () async {
            // The design's bookmark icon opens the save sheet every time, so
            // a place that is already saved can still have its folders
            // changed -- and the sheet is where it can be unsaved. A second
            // tap used to remove it on the spot, silently, which left no way
            // to reach the folders again.
            if (!bookmarked) {
              await bookmarkProvider.addBookmark(placeId);
              if (!context.mounted) return;

              // Whatever went wrong, say so: a bookmark that quietly does
              // nothing reads as a broken button.
              final error = bookmarkProvider.errorMessage;
              if (error != null) {
                bookmarkProvider.clearError();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(error)));
                return;
              }

              onBookmarked?.call();
            }

            final bookmarkId = bookmarkProvider.bookmarkIdFor(placeId);
            if (bookmarkId == null || !context.mounted) return;
            await showBookmarkFolderSheet(context, bookmarkId: bookmarkId, placeId: placeId);
          },
          icon: Icon(
            bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: bookmarked ? colorScheme.primary : colorScheme.onSurfaceVariant,
            size: compact ? 21 : null,
          ),
          visualDensity: compact ? VisualDensity.compact : null,
          tooltip: bookmarked ? '북마크 해제' : '북마크',
        );
      },
    );
  }
}

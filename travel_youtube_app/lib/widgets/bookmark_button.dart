import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/bookmark_provider.dart';

class BookmarkButton extends StatelessWidget {
  final String placeId;

  const BookmarkButton({super.key, required this.placeId});

  @override
  Widget build(BuildContext context) {
    return Consumer<BookmarkProvider>(
      builder: (context, bookmarkProvider, _) {
        final bookmarked = bookmarkProvider.isBookmarked(placeId);
        final colorScheme = Theme.of(context).colorScheme;

        return IconButton(
          onPressed: () => bookmarkProvider.toggleBookmark(placeId),
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

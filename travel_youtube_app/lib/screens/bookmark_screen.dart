import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/bookmark_provider.dart';
import '../providers/itinerary_provider.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/place_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_center.dart';

class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({super.key});

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookmarkProvider>().loadBookmarks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookmarkProvider = context.watch<BookmarkProvider>();
    final itineraryProvider = context.watch<ItineraryProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('북마크')),
      body: Builder(
        builder: (context) {
          if (bookmarkProvider.isLoading &&
              bookmarkProvider.bookmarks.isEmpty) {
            return const LoadingIndicator();
          }
          if (bookmarkProvider.state == ViewState.error &&
              bookmarkProvider.bookmarks.isEmpty) {
            return ErrorView(
              message: bookmarkProvider.errorMessage ?? '북마크를 불러오지 못했습니다.',
              onRetry: () => bookmarkProvider.loadBookmarks(),
            );
          }
          if (bookmarkProvider.bookmarks.isEmpty) {
            return const Center(child: Text('북마크한 장소가 없습니다.'));
          }

          return ResponsiveCenter(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '동선에 포함할 장소를 2~10개 선택하세요 (${itineraryProvider.selectedPlaceIds.length}개 선택됨)',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: bookmarkProvider.bookmarks.length,
                    itemBuilder: (context, index) {
                      final bookmark = bookmarkProvider.bookmarks[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: PlaceCard(
                          placeId: bookmark.placeId,
                          name: bookmark.name,
                          address: bookmark.address,
                          timestampSec: bookmark.timestampSec,
                          selected: itineraryProvider.isSelected(
                            bookmark.placeId,
                          ),
                          onSelectedChanged: (_) => itineraryProvider
                              .togglePlaceSelection(bookmark.placeId),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: PrimaryButton(
                    label: '동선 만들기',
                    icon: Icons.alt_route_rounded,
                    onPressed: itineraryProvider.canOptimize
                        ? () => Navigator.pushNamed(
                            context,
                            AppRoutes.routePlanner,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

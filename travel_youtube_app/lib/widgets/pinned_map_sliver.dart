import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'responsive_center.dart';

/// A route map that stays pinned at the top of a [CustomScrollView] while the
/// stop list scrolls beneath it. In a plain scroll view the map scrolled away
/// with the first stop, so tapping a stop further down moved a map nobody
/// could see. Used by the walking course result and shared route detail
/// screens; [map] is whatever `MapRepository.buildMap` returns.
class PinnedMapSliver extends StatelessWidget {
  const PinnedMapSliver({super.key, required this.map});

  final Widget map;

  static const double mapHeight = 180;
  static const double verticalPadding = 12;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _PinnedMapHeaderDelegate(
        child: ColoredBox(
          color: Colors.white,
          child: ResponsiveCenter(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: verticalPadding,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: map,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinnedMapHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedMapHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent =>
      PinnedMapSliver.mapHeight + PinnedMapSliver.verticalPadding * 2;

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  // The child carries the selected stop, so it must rebuild when that changes.
  @override
  bool shouldRebuild(_PinnedMapHeaderDelegate oldDelegate) =>
      child != oldDelegate.child;
}

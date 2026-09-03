import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/trip_model.dart';
import '../utils/widget_image_capture.dart';
import '../widgets/itinerary_share_card.dart';

/// Renders a trip's overview + one card per day as PNG images and hands
/// them to the platform's native share sheet in a single action. Pure
/// client-side rendering/file work with no backend call, so this lives
/// alongside `kakao_auth_service.dart`/`map_service.dart` as a platform
/// integration service rather than a Provider/Repository.
class ItineraryShareService {
  const ItineraryShareService();

  static const double _cardWidth = 420;
  static const double _pixelRatio = 3.0;

  /// Renders [trip]'s overview + per-day cards, saves them to the app's
  /// temp directory, opens the share sheet, then deletes the temp files
  /// regardless of whether the user actually shared or cancelled.
  Future<void> shareTrip({required BuildContext context, required TripDetailModel trip}) async {
    final files = <File>[];

    try {
      final tempDir = await getTemporaryDirectory();
      if (!context.mounted) return;

      final overviewBytes = await captureWidgetPng(
        context: context,
        width: _cardWidth,
        pixelRatio: _pixelRatio,
        child: ItineraryOverviewShareCard(
          tripName: trip.name,
          createdAt: trip.createdAt,
          days: trip.days,
        ),
      );
      final overviewFile = File('${tempDir.path}/voylog_share_overview.png');
      await overviewFile.writeAsBytes(overviewBytes);
      files.add(overviewFile);

      for (final day in trip.days) {
        if (!context.mounted) break;
        final dayBytes = await captureWidgetPng(
          context: context,
          width: _cardWidth,
          pixelRatio: _pixelRatio,
          child: ItineraryShareCard(
            tripName: trip.name,
            dayNumber: day.dayNumber,
            day: day,
          ),
        );
        final dayFile = File('${tempDir.path}/voylog_share_day${day.dayNumber}.png');
        await dayFile.writeAsBytes(dayBytes);
        files.add(dayFile);
      }

      await SharePlus.instance.share(
        ShareParams(
          files: files.map((f) => XFile(f.path)).toList(),
          text: '${trip.name} · Voylog로 만든 여행 일정',
        ),
      );
    } finally {
      for (final file in files) {
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
  }
}

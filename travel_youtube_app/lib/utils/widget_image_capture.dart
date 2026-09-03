import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Renders [child] off-screen (positioned far outside the visible viewport,
/// never shown to the user) and returns it as PNG bytes. Used to generate
/// share-card images from data-driven widgets instead of screenshotting the
/// visible UI -- lets a share card use a fixed layout independent of
/// whatever is actually on screen (and avoids capturing WebView-backed
/// content such as Kakao Maps, which doesn't render into a
/// `RenderRepaintBoundary` reliably).
///
/// [width] is fixed (logical pixels); height sizes naturally to [child]'s
/// content. [pixelRatio] scales the output resolution (e.g. 3.0 for a sharp
/// image on a 1x-logical-width canvas).
Future<Uint8List> captureWidgetPng({
  required BuildContext context,
  required Widget child,
  required double width,
  double pixelRatio = 3.0,
}) async {
  final repaintKey = GlobalKey();
  final overlay = Overlay.of(context, rootOverlay: true);

  final entry = OverlayEntry(
    builder: (context) => Positioned(
      left: -10000,
      top: 0,
      child: Material(
        color: Colors.transparent,
        child: RepaintBoundary(
          key: repaintKey,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );

  overlay.insert(entry);

  try {
    // Two frames: one to lay out and paint the freshly-inserted entry, a
    // second to make sure everything (fonts, images) has settled before we
    // read pixels back out of it.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  } finally {
    entry.remove();
  }
}

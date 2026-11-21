import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// High-DPI rendering service to rasterize Story Card widgets into crystal-clear PNG images.
class StoryCardRenderService {
  const StoryCardRenderService();

  /// Captures PNG bytes from the [GlobalKey] attached to a [RepaintBoundary].
  ///
  /// Uses a high default [pixelRatio] (3.5x) to guarantee export resolutions of at least
  /// 1080p+ (e.g. 1330x2364 for 9:16 stories) with smooth anti-aliased typography.
  Future<Uint8List?> capturePng(
    GlobalKey repaintKey, {
    double pixelRatio = 3.5,
  }) async {
    try {
      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        return byteData?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } catch (e) {
      debugPrint('StoryCardRenderService: capture failed: $e');
      return null;
    }
  }
}

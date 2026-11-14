import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Tier 1 universal on-device semantic embedding service backed by
/// MediaPipe Tasks Text + Universal Sentence Encoder (.tflite) on Android.
class LiteRtService {
  static const MethodChannel _channel = MethodChannel('com.saadhjawwadh.notebook/litert');
  static const Duration _inferenceTimeout = Duration(milliseconds: 500);
  static const Duration _supportTimeout = Duration(seconds: 2);

  LiteRtService._();
  static final LiteRtService instance = LiteRtService._();

  bool? _cachedSupport;

  Future<bool> isSupported() async {
    if (_cachedSupport != null) return _cachedSupport!;
    if (kIsWeb || !Platform.isAndroid) {
      _cachedSupport = false;
      return false;
    }
    try {
      final result = await _channel
          .invokeMethod<bool>('isSupported')
          .timeout(_supportTimeout);
      _cachedSupport = result ?? false;
    } catch (_) {
      _cachedSupport = false;
    }
    return _cachedSupport!;
  }

  /// Scores [text] against each candidate in [labels] using cosine similarity.
  /// Returns an empty map on timeout, unsupported platform, or native error.
  Future<Map<String, double>> scoreLabels({
    required String text,
    required List<String> labels,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || labels.isEmpty) return {};
    if (!await isSupported()) return {};

    try {
      final raw = await _channel
          .invokeMapMethod<String, double>('scoreLabels', {
            'text': trimmed,
            'labels': labels,
          })
          .timeout(_inferenceTimeout);
      return raw ?? {};
    } catch (_) {
      return {};
    }
  }

  /// Returns the highest-scoring label if its score meets [minConfidence]
  /// (and optionally exceeds the runner-up by [minMargin]).
  Future<String?> classifyBestLabel({
    required String text,
    required List<String> labels,
    double minConfidence = 0.25,
    double minMargin = 0.02,
  }) async {
    final scores = await scoreLabels(text: text, labels: labels);
    if (scores.isEmpty) return null;

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = sorted.first;
    if (top.value < minConfidence) return null;
    if (sorted.length > 1 && (top.value - sorted[1].value) < minMargin) {
      return null;
    }
    return top.key;
  }

  /// Returns up to [maxResults] labels meeting [minConfidence], sorted descending.
  Future<List<String>> suggestTopLabels({
    required String text,
    required List<String> labels,
    int maxResults = 3,
    double minConfidence = 0.25,
  }) async {
    final scores = await scoreLabels(text: text, labels: labels);
    if (scores.isEmpty) return [];

    final sorted = scores.entries
        .where((e) => e.value >= minConfidence)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(maxResults).map((e) => e.key).toList();
  }

  Future<void> clearLabelCache() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('clearLabelCache').timeout(_supportTimeout);
    } catch (_) {
      // Ignore cache clear failures
    }
  }

  /// Strips SMS/POS noise (phone numbers, city/country codes, corporate suffixes,
  /// trailing prepositions) so both personal-history lookup and semantic embeddings
  /// operate on clean merchant names.
  static String normalizeMerchantText(String raw) {
    var cleaned = raw.trim();
    if (cleaned.isEmpty) return '';

    // Strip corporate suffixes like (PVT) LTD, PVT LTD, PLC, INC
    cleaned = cleaned.replaceAll(
      RegExp(r'\(?\s*PVT\s*\)?\s*LTD\.?|\bPVT\s+LTD\b|\bPLC\b|\bINC\b', caseSensitive: false),
      ' ',
    );

    // Strip Sri Lankan / POS location tokens like COLOMBO-3, COLOMBO, RATMALANA, LK, LKA
    cleaned = cleaned.replaceAll(
      RegExp(r'\bCOLOMBO(?:-\d+)?\b|\bRATMALANA\b|\bLKA?\b', caseSensitive: false),
      ' ',
    );

    // Strip phone numbers or long numeric POS reference tokens (7-12 digits)
    cleaned = cleaned.replaceAll(RegExp(r'\b0\d{8,10}\b|\b\d{7,12}\b'), ' ');

    // Strip trailing prepositions left by truncated bank SMS templates (e.g. "PickMe Food ... for ")
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(?:for|at|via|to|from)\s*$', caseSensitive: false),
      '',
    );

    // Collapse whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../../services/gemini_nano_service.dart';

class ParsedReceiptResult {
  final double? totalAmount;
  final String? merchantTitle;
  final DateTime? date;
  final String rawText;
  final List<String> detectedLineItems;

  const ParsedReceiptResult({
    this.totalAmount,
    this.merchantTitle,
    this.date,
    required this.rawText,
    this.detectedLineItems = const [],
  });
}

class ReceiptScannerService {
  static final ReceiptScannerService instance = ReceiptScannerService._();
  ReceiptScannerService._();

  Future<ParsedReceiptResult?> processReceiptImage(
    String imagePath, {
    bool isAiActive = false,
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) return null;

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      final rawText = recognizedText.text;

      if (rawText.trim().isEmpty) {
        return const ParsedReceiptResult(rawText: '');
      }

      // Check on-device AI first if enabled
      if (isAiActive) {
        final aiResult = await _parseWithOnDeviceAi(rawText);
        if (aiResult != null && aiResult.totalAmount != null) {
          return aiResult;
        }
      }

      // Rule-based heuristic extraction fallback
      return _parseWithRegexHeuristics(rawText);
    } catch (e) {
      debugPrint('[ReceiptScannerService] Error scanning receipt: $e');
      return null;
    } finally {
      await textRecognizer.close();
    }
  }

  Future<ParsedReceiptResult?> _parseWithOnDeviceAi(String rawText) async {
    try {
      final nano = GeminiNanoService();
      if (!await nano.isSupported()) return null;

      final prompt = """
You are an offline receipt parser. Analyze the OCR text below from a receipt and extract the details in valid JSON format:
{
  "title": "Merchant or restaurant name (e.g. Botanik Rooftop)",
  "total": 12500.00
}

STRICT INSTRUCTIONS:
- Respond with ONLY the JSON object. Do not include markdown formatting or commentary.
- "total" MUST be a pure numerical number without currency symbols.

OCR Text:
$rawText
""";

      final response = await nano.generateText(prompt);
      if (response != null && response.trim().isNotEmpty) {
        final cleanJson = response.replaceAll('```json', '').replaceAll('```', '').trim();
        final totalMatch = RegExp(r'"total"\s*:\s*([\d\.]+)').firstMatch(cleanJson);
        final titleMatch = RegExp(r'"title"\s*:\s*"([^"]+)"').firstMatch(cleanJson);

        final total = totalMatch != null ? double.tryParse(totalMatch.group(1)!) : null;
        final title = titleMatch?.group(1);

        if (total != null && total > 0) {
          return ParsedReceiptResult(
            totalAmount: total,
            merchantTitle: title,
            rawText: rawText,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  ParsedReceiptResult _parseWithRegexHeuristics(String rawText) {
    final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    double? detectedTotal;
    String? candidateMerchant;

    // First 3 lines often contain the store / restaurant name
    for (int i = 0; i < lines.length && i < 3; i++) {
      final line = lines[i];
      if (line.length >= 3 && !RegExp(r'^\d+$').hasMatch(line) && !line.toLowerCase().contains('tel') && !line.toLowerCase().contains('tax')) {
        candidateMerchant = line;
        break;
      }
    }

    // Search lines from bottom up for total keywords
    final totalKeywords = [
      RegExp(r'(?:grand\s*total|net\s*amount|bill\s*total|total\s*due|total\s*amount|total|net|amount\s*payable)', caseSensitive: false),
      RegExp(r'(?:sub\s*total|subtotal|balance\s*due)', caseSensitive: false),
    ];

    for (final pattern in totalKeywords) {
      if (detectedTotal != null) break;
      for (int i = lines.length - 1; i >= 0; i--) {
        final line = lines[i];
        if (pattern.hasMatch(line)) {
          // Look for amount in this line or subsequent line
          final amountMatch = RegExp(r'(?:rs\.?|lkr|\$|€|£)?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)', caseSensitive: false).allMatches(line);
          for (final m in amountMatch) {
            final rawNum = m.group(1)?.replaceAll(',', '');
            if (rawNum != null) {
              final val = double.tryParse(rawNum);
              if (val != null && val > 0) {
                detectedTotal = val;
                break;
              }
            }
          }

          if (detectedTotal == null && i + 1 < lines.length) {
            // Check next line for standalone amount
            final nextLine = lines[i + 1];
            final nextMatch = RegExp(r'([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)').firstMatch(nextLine);
            if (nextMatch != null) {
              final val = double.tryParse(nextMatch.group(1)!.replaceAll(',', ''));
              if (val != null && val > 0) {
                detectedTotal = val;
                break;
              }
            }
          }
          if (detectedTotal != null) break;
        }
      }
    }

    // Fallback: search for the highest plausible number in the bottom half of the receipt
    if (detectedTotal == null) {
      double maxFound = 0.0;
      final searchText = lines.length >= 4
          ? lines.sublist(lines.length ~/ 2).join('\n')
          : rawText;
      final numbers = RegExp(r'\b([0-9]{2,6}(?:\.[0-9]{2})?)\b').allMatches(searchText);
      for (final n in numbers) {
        final val = double.tryParse(n.group(1)!);
        if (val != null && val > maxFound && val < 5000000) {
          maxFound = val;
        }
      }
      if (maxFound > 0) {
        detectedTotal = maxFound;
      }
    }

    return ParsedReceiptResult(
      totalAmount: detectedTotal,
      merchantTitle: candidateMerchant,
      rawText: rawText,
      detectedLineItems: lines,
    );
  }
}

abstract class LocalAiService {
  /// Checks if the device's hardware supports Gemini Nano and AI Core is ready.
  Future<bool> isSupported();

  /// Generates a response based on a prompt.
  Future<String?> generateText(String prompt);

  /// Summarizes a block of text.
  Future<String?> summarize(String text);

  /// Suggests a list of tags for a note.
  Future<List<String>> suggestTags(String noteContent, List<String> existingTags);

  /// Parses transaction details from a bank SMS using the active list of categories.
  /// Returns a map with keys: 'amount' (double), 'merchant' (string), 'category' (string), and 'isExpense' (bool).
  Future<Map<String, dynamic>?> parseSmsTransaction(String smsBody, List<String> categories);

  /// Refines a raw transaction description into a clean, human-readable merchant name or purpose.
  Future<String?> refineTransactionDescription(String rawDescription, String smsBody);

  /// Refines the provided text based on a selection mode (e.g. polish, shorten, expand, professional, casual).
  Future<String?> refineText(String text, String mode);

  /// Parses a natural-language user query into a structured A2UI action map
  /// (e.g. transaction, split_bill, todo, note) using on-device AI or deterministic NLP fallback.
  Future<Map<String, dynamic>?> parseNaturalLanguageAction(
    String query,
    List<String> categories,
  );
}

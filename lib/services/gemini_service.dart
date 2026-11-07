import 'package:google_generative_ai/google_generative_ai.dart';
import 'security_service.dart';

class GeminiService {
  static final GeminiService instance = GeminiService._init();
  GeminiService._init();

  /// Queries Google Gemini with local financial context if an API key is configured.
  /// Returns null if no API key is configured (triggering fallback to local QueryEngine).
  Future<String?> askFinancialQuestion({
    required String question,
    required String financialContext,
  }) async {
    final apiKey = await SecurityService.instance.getGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return null; // Fall back to local rules-based engine
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(
          'You are LedgerLens AI, an expert private Indian personal finance assistant. '
          'You analyze the user\'s Indian banking statements (HDFC, SBI, ICICI, Axis). '
          'Always use Indian Rupee (₹) formatting and Lakhs/Crores when appropriate. '
          'Keep your answers concise, structured, and helpful. Never invent numbers; '
          'only rely on the provided financial context.',
        ),
      );

      final prompt = '''
User Transactions Context:
$financialContext

User Question:
$question
''';

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text;
    } catch (_) {
      return null; // Fall back to local QueryEngine on network or quota errors
    }
  }

  /// AI-assisted categorization fallback for ambiguous narrations when API key is set.
  Future<Map<String, dynamic>?> categorizeWithAI({
    required String cleanMerchant,
    required String rawDescription,
  }) async {
    final apiKey = await SecurityService.instance.getGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      final prompt = '''
Categorize this Indian bank narration into one of these exact categories:
- Food & Dining
- Shopping
- Investments & SIP
- Transport & Fuel
- Bills & Utilities
- Entertainment
- Salary & Income
- Other

Merchant: $cleanMerchant
Raw Narration: $rawDescription

Respond with ONLY the exact category name.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final category = response.text?.trim() ?? 'Other';
      return {
        'categoryName': category,
        'confidence': 0.85,
      };
    } catch (_) {
      return null;
    }
  }
}


class CategorizationResult {
  final String categoryName;
  final String categoryId;
  final double confidence;
  final String reviewStatus; // 'auto' or 'needs_review'

  const CategorizationResult({
    required this.categoryName,
    required this.categoryId,
    required this.confidence,
    required this.reviewStatus,
  });
}

class CategorizerService {
  static const double confidenceThreshold = 0.70;

  // Keyword rules table for Indian banking
  static final Map<String, List<String>> _categoryKeywords = {
    'Food & Dining': [
      'swiggy', 'zomato', 'blinkit', 'zepto', 'starbucks', 'mcdonalds',
      'dominos', 'kfc', 'cafe', 'restaurant', 'food', 'bakery', 'pizzahut',
      'subway', 'chai', 'coffee', 'barbeque', 'haldiram'
    ],
    'Shopping': [
      'amazon', 'flipkart', 'myntra', 'nykaa', 'ajio', 'tata cliq',
      'zara', 'h&m', 'decathlon', 'reliancedigital', 'croma', 'ikea',
      'marks and spencer', 'lifestyle', 'westside', 'uniqlo'
    ],
    'Investments & SIP': [
      'zerodha', 'groww', 'mutual fund', 'sip', 'upstox', 'angelone',
      'kuvera', 'camsonline', 'kfintech', 'uti', 'sbi mutual', 'hdfc mutual',
      'icici pru mutual', 'parag parikh', 'mirae asset', 'nippon', 'ppfas'
    ],
    'Transport & Fuel': [
      'uber', 'ola', 'rapido', 'namma yatri', 'irctc', 'indigo', 'air india',
      'hpcl', 'bpcl', 'iocl', 'petrol', 'fuel', 'fastag', 'metro', 'shell'
    ],
    'Bills & Utilities': [
      'bescom', 'tneb', 'mseb', 'electricity', 'airtel', 'jio', 'vi',
      'tatasky', 'tata play', 'billdesk', 'broadband', 'act fibernet',
      'water board', 'gas', 'indane', 'bharatgas', 'hpgas'
    ],
    'Entertainment': [
      'netflix', 'spotify', 'prime video', 'youtube', 'hotstar', 'disney',
      'bookmyshow', 'pvr', 'inox', 'apple.com/bill', 'audible', 'steam'
    ],
    'Salary & Income': [
      'salary credit', 'salary', 'payroll', 'consulting', 'interest paid',
      'dividend', 'refund', 'reimbursement'
    ],
  };

  /// 3-Stage Categorization Pipeline
  static CategorizationResult categorize({
    required String cleanMerchant,
    required String rawDescription,
    required String direction,
  }) {
    final lowerClean = cleanMerchant.toLowerCase();
    final lowerRaw = rawDescription.toLowerCase();

    // Stage 1 & 2: Rule-based Keyword Matching & Confidence Scoring
    if (direction == 'credit') {
      if (lowerRaw.contains('salary') || lowerClean.contains('salary')) {
        return const CategorizationResult(
          categoryName: 'Salary & Income',
          categoryId: 'cat_income',
          confidence: 0.99,
          reviewStatus: 'auto',
        );
      }
      if (lowerRaw.contains('refund') || lowerClean.contains('refund')) {
        return const CategorizationResult(
          categoryName: 'Salary & Income',
          categoryId: 'cat_income',
          confidence: 0.54, // Ambiguous refund source -> Needs Review
          reviewStatus: 'needs_review',
        );
      }
      if (lowerRaw.contains('int.pd') || lowerRaw.contains('interest')) {
        return const CategorizationResult(
          categoryName: 'Salary & Income',
          categoryId: 'cat_income',
          confidence: 0.95,
          reviewStatus: 'auto',
        );
      }
    }

    // Check against category keyword dictionary
    for (final entry in _categoryKeywords.entries) {
      final category = entry.key;
      final keywords = entry.value;

      for (final kw in keywords) {
        if (lowerClean.contains(kw)) {
          return CategorizationResult(
            categoryName: category,
            categoryId: _getCategoryId(category),
            confidence: 0.95,
            reviewStatus: 'auto',
          );
        }
        if (lowerRaw.contains(kw)) {
          return CategorizationResult(
            categoryName: category,
            categoryId: _getCategoryId(category),
            confidence: 0.88,
            reviewStatus: 'auto',
          );
        }
      }
    }

    // Heuristics for POS / Unknown Cards
    if (lowerRaw.startsWith('pos') || lowerRaw.contains('pos ')) {
      return const CategorizationResult(
        categoryName: 'Food & Dining',
        categoryId: 'cat_food',
        confidence: 0.62, // Ambiguous POS location -> Needs Review
        reviewStatus: 'needs_review',
      );
    }

    // Fallback: Low confidence quarantine
    return const CategorizationResult(
      categoryName: 'Other',
      categoryId: 'cat_other',
      confidence: 0.40,
      reviewStatus: 'needs_review',
    );
  }

  static String _getCategoryId(String name) {
    switch (name) {
      case 'Food & Dining': return 'cat_food';
      case 'Shopping': return 'cat_shopping';
      case 'Investments & SIP': return 'cat_investments';
      case 'Transport & Fuel': return 'cat_transport';
      case 'Bills & Utilities': return 'cat_bills';
      case 'Entertainment': return 'cat_entertainment';
      case 'Salary & Income': return 'cat_income';
      default: return 'cat_other';
    }
  }
}


import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlens/models/transaction_model.dart';
import 'package:ledgerlens/services/categorizer.dart';
import 'package:ledgerlens/services/query_engine.dart';

void main() {
  group('Security & Fallback Unit Tests', () {
    test('Zero hardcoded keys: Rules-only categorization works 100% offline without API key', () {
      final res = CategorizerService.categorize(
        cleanMerchant: 'Zomato Ltd',
        rawDescription: 'UPI/CR/429102918291/Zomato Ltd',
        direction: 'debit',
      );
      expect(res.categoryName, equals('Food & Dining'));
      expect(res.confidence, greaterThanOrEqualTo(0.90));
      expect(res.reviewStatus, equals('auto'));
    });

    test('Zero hardcoded keys: Local QueryEngine works 100% offline without API key', () {
      final txns = [
        TransactionModel(
          id: '1',
          date: '2024-10-01',
          amount: 21500000,
          direction: 'credit',
          rawDescription: 'SALARY CREDIT - GOOGLE INDIA',
          cleanMerchantName: 'Google India',
          categoryName: 'Salary & Income',
          hash: 'h1',
        ),
      ];

      final queryResult = QueryEngine.executeQuery('Did I receive salary?', txns);
      expect(queryResult.answer, contains('Google India'));
      expect(queryResult.totalAmount, equals(215000.0));
    });

    test('Threshold quarantine for unverified merchants', () {
      final res = CategorizerService.categorize(
        cleanMerchant: 'Random Unregistered Merchant',
        rawDescription: 'UPI/4281928391/RANDOM_MERCHANT/SHOP',
        direction: 'debit',
      );
      expect(res.reviewStatus, equals('needs_review'));
      expect(res.confidence, lessThan(CategorizerService.confidenceThreshold));
    });
  });
}


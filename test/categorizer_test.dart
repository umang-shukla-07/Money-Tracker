import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlens/services/categorizer.dart';

void main() {
  group('CategorizerService 3-Stage Tests', () {
    test('Stage 1: Matches Food & Dining merchants with high confidence', () {
      final res1 = CategorizerService.categorize(
        cleanMerchant: 'Swiggy',
        rawDescription: 'UPI/428381928391/Swiggy/swiggy@icici',
        direction: 'debit',
      );
      expect(res1.categoryName, equals('Food & Dining'));
      expect(res1.confidence, greaterThanOrEqualTo(0.90));
      expect(res1.reviewStatus, equals('auto'));

      final res2 = CategorizerService.categorize(
        cleanMerchant: 'Zomato Ltd',
        rawDescription: 'UPI/CR/429102918291/Zomato Ltd',
        direction: 'debit',
      );
      expect(res2.categoryName, equals('Food & Dining'));
      expect(res2.reviewStatus, equals('auto'));
    });

    test('Stage 1: Matches Investments & SIP with high confidence', () {
      final res = CategorizerService.categorize(
        cleanMerchant: 'Zerodha Broking',
        rawDescription: 'ACH Dr-ZERODHA BROKING-MUTUAL FUND SIP 12345',
        direction: 'debit',
      );
      expect(res.categoryName, equals('Investments & SIP'));
      expect(res.confidence, greaterThanOrEqualTo(0.95));
      expect(res.reviewStatus, equals('auto'));
    });

    test('Stage 1: Matches Utilities & Bills with high confidence', () {
      final res = CategorizerService.categorize(
        cleanMerchant: 'Bescom Electricity',
        rawDescription: 'BILLDESK*BESCOM*ELECTRICITY 492019',
        direction: 'debit',
      );
      expect(res.categoryName, equals('Bills & Utilities'));
      expect(res.confidence, greaterThanOrEqualTo(0.90));
      expect(res.reviewStatus, equals('auto'));
    });

    test('Stage 1: Matches Salary Credit with 0.99 confidence', () {
      final res = CategorizerService.categorize(
        cleanMerchant: 'Google India Pvt Ltd',
        rawDescription: 'SALARY CREDIT - OCT 2024 - GOOGLE INDIA PVT LTD',
        direction: 'credit',
      );
      expect(res.categoryName, equals('Salary & Income'));
      expect(res.confidence, equals(0.99));
      expect(res.reviewStatus, equals('auto'));
    });

    test('Stage 2 & 3: Quarantines ambiguous refund into review queue', () {
      final res = CategorizerService.categorize(
        cleanMerchant: 'Amit Sharma',
        rawDescription: 'NEFT-CR-AXIS000123-AMIT SHARMA-REFUND',
        direction: 'credit',
      );
      expect(res.categoryName, equals('Salary & Income'));
      expect(res.confidence, lessThan(CategorizerService.confidenceThreshold));
      expect(res.reviewStatus, equals('needs_review'));
    });

    test('Stage 2 & 3: Quarantines ambiguous POS swipe into review queue', () {
      final res = CategorizerService.categorize(
        cleanMerchant: 'Unknown Store',
        rawDescription: 'POS 421456XXXXXX1234 STORE BLR IN',
        direction: 'debit',
      );
      expect(res.confidence, lessThan(CategorizerService.confidenceThreshold));
      expect(res.reviewStatus, equals('needs_review'));
    });

    test('Stage 2 & 3: Quarantines completely unknown narration', () {
      final res = CategorizerService.categorize(
        cleanMerchant: 'Misc Transfer',
        rawDescription: 'TRF 991823910291 MISC',
        direction: 'debit',
      );
      expect(res.categoryName, equals('Other'));
      expect(res.confidence, lessThan(0.50));
      expect(res.reviewStatus, equals('needs_review'));
    });
  });
}


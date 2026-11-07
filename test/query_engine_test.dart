import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlens/models/transaction_model.dart';
import 'package:ledgerlens/services/query_engine.dart';

void main() {
  group('QueryEngine Unit Tests', () {
    final sampleTxns = [
      TransactionModel(
        id: '1',
        date: '2024-10-01',
        amount: 21500000, // ₹2,15,000.00
        direction: 'credit',
        rawDescription: 'SALARY CREDIT - OCT 2024 - GOOGLE INDIA PVT LTD',
        cleanMerchantName: 'Google India Pvt Ltd',
        categoryName: 'Salary & Income',
        hash: 'h1',
      ),
      TransactionModel(
        id: '2',
        date: '2024-10-02',
        amount: 2500000, // ₹25,000.00
        direction: 'debit',
        rawDescription: 'ACH Dr-ZERODHA BROKING-MUTUAL FUND SIP 12345',
        cleanMerchantName: 'Zerodha Mutual Fund SIP',
        categoryName: 'Investments & SIP',
        hash: 'h2',
      ),
      TransactionModel(
        id: '3',
        date: '2024-10-03',
        amount: 64250, // ₹642.50
        direction: 'debit',
        rawDescription: 'UPI/428381928391/Swiggy/swiggy@icici/Order 92831',
        cleanMerchantName: 'Swiggy',
        categoryName: 'Food & Dining',
        hash: 'h3',
      ),
      TransactionModel(
        id: '4',
        date: '2024-10-04',
        amount: 42000, // ₹420.00
        direction: 'debit',
        rawDescription: 'POS 421456XXXXXX1234 STARBUCKS BANGALORE IN',
        cleanMerchantName: 'Starbucks Bangalore',
        categoryName: 'Food & Dining',
        hash: 'h4',
      ),
      TransactionModel(
        id: '5',
        date: '2024-10-05',
        amount: 285000, // ₹2,850.00
        direction: 'debit',
        rawDescription: 'BILLDESK*BESCOM*ELECTRICITY 492019',
        cleanMerchantName: 'BESCOM Electricity Bill',
        categoryName: 'Bills & Utilities',
        hash: 'h5',
      ),
    ];

    test('Answers salary queries accurately', () {
      final res = QueryEngine.executeQuery('Did I receive salary?', sampleTxns);
      expect(res.answer, contains('Google India Pvt Ltd'));
      expect(res.answer, contains('₹2,15,000.00'));
      expect(res.totalAmount, equals(215000.0));
      expect(res.matchedTransactions.length, equals(1));
    });

    test('Answers dining & coffee queries with aggregated total', () {
      final res = QueryEngine.executeQuery('How much did I spend on dining and coffee?', sampleTxns);
      expect(res.totalAmount, equals(1062.50));
      expect(res.answer, contains('₹1,062.50'));
      expect(res.matchedTransactions.length, equals(2));
    });

    test('Answers SIP & investment queries', () {
      final res = QueryEngine.executeQuery('How much did I invest in SIPs?', sampleTxns);
      expect(res.totalAmount, equals(25000.0));
      expect(res.answer, contains('₹25,000.00'));
      expect(res.matchedTransactions.length, equals(1));
    });

    test('Answers utility and bill queries', () {
      final res = QueryEngine.executeQuery('What was my electricity bill?', sampleTxns);
      expect(res.totalAmount, equals(2850.0));
      expect(res.answer, contains('₹2,850.00'));
      expect(res.matchedTransactions.length, equals(1));
    });

    test('Answers UPI queries', () {
      final res = QueryEngine.executeQuery('List all UPI payments', sampleTxns);
      expect(res.matchedTransactions.length, equals(1));
      expect(res.totalAmount, equals(642.50));
    });

    test('Answers net savings and cashflow queries', () {
      final res = QueryEngine.executeQuery('What is my total savings and cashflow?', sampleTxns);
      // Income: 215000, Expense: 25000 + 642.50 + 420 + 2850 = 28912.50 -> Net: 186087.50
      expect(res.totalAmount, equals(186087.50));
      expect(res.answer, contains('1,86,087.50'));
    });

    test('Handles unknown query gracefully', () {
      final res = QueryEngine.executeQuery('How much did I spend on jet skis?', sampleTxns);
      expect(res.answer, contains("I couldn't find any transactions related to"));
      expect(res.totalAmount, isNull);
    });
  });
}


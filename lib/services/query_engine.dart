import 'package:intl/intl.dart';
import '../models/transaction_model.dart';

class QueryResult {
  final String answer;
  final double? totalAmount;
  final List<TransactionModel> matchedTransactions;

  const QueryResult({
    required this.answer,
    this.totalAmount,
    this.matchedTransactions = const [],
  });
}

class QueryEngine {
  static final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  /// Executes natural language financial query planning and local execution.
  static QueryResult executeQuery(String query, List<TransactionModel> transactions) {
    if (query.trim().isEmpty) {
      return const QueryResult(answer: 'Please enter a question about your finances.');
    }

    final q = query.toLowerCase().trim();

    // 1. Salary Queries
    if (q.contains('salary') || q.contains('payroll')) {
      final salaryTxns = transactions.where((t) =>
          t.isCredit &&
          (t.categoryName.toLowerCase().contains('salary') ||
              t.cleanMerchantName.toLowerCase().contains('salary') ||
              t.rawDescription.toLowerCase().contains('salary'))).toList();

      if (salaryTxns.isEmpty) {
        return const QueryResult(
          answer: 'No salary credit was found in the recorded transactions.',
        );
      }

      final total = salaryTxns.fold<int>(0, (sum, t) => sum + t.amount) / 100.0;
      final latest = salaryTxns.first;
      return QueryResult(
        answer:
            'Yes! You received ${_inr.format(total)} in salary credits. Latest was ${_inr.format(latest.amountRupees)} from ${latest.cleanMerchantName} on ${latest.date}.',
        totalAmount: total,
        matchedTransactions: salaryTxns,
      );
    }

    // 2. Dining / Food & Coffee Queries
    if (q.contains('dining') || q.contains('food') || q.contains('coffee') || q.contains('swiggy') || q.contains('starbucks')) {
      final diningTxns = transactions.where((t) =>
          t.isDebit &&
          (t.categoryName == 'Food & Dining' ||
              t.cleanMerchantName.toLowerCase().contains('swiggy') ||
              t.cleanMerchantName.toLowerCase().contains('zomato') ||
              t.cleanMerchantName.toLowerCase().contains('starbucks'))).toList();

      if (diningTxns.isEmpty) {
        return const QueryResult(answer: 'No dining or coffee expenses found for this period.');
      }

      final total = diningTxns.fold<int>(0, (sum, t) => sum + t.amount) / 100.0;
      final summary = diningTxns.take(3).map((t) => '${t.cleanMerchantName}: ${_inr.format(t.amountRupees)} on ${t.date}').join(', ');

      return QueryResult(
        answer: 'You spent ${_inr.format(total)} on Food & Dining across ${diningTxns.length} transactions ($summary).',
        totalAmount: total,
        matchedTransactions: diningTxns,
      );
    }

    // 3. Investments & SIP Queries
    if (q.contains('sip') || q.contains('invest') || q.contains('zerodha') || q.contains('mutual fund') || q.contains('groww')) {
      final sipTxns = transactions.where((t) =>
          t.categoryName == 'Investments & SIP' ||
          t.cleanMerchantName.toLowerCase().contains('zerodha') ||
          t.cleanMerchantName.toLowerCase().contains('sip') ||
          t.cleanMerchantName.toLowerCase().contains('mutual fund')).toList();

      if (sipTxns.isEmpty) {
        return const QueryResult(answer: 'No investment or SIP transactions found.');
      }

      final total = sipTxns.fold<int>(0, (sum, t) => sum + t.amount) / 100.0;
      return QueryResult(
        answer: 'You invested ${_inr.format(total)} in Mutual Funds & SIPs across ${sipTxns.length} transactions.',
        totalAmount: total,
        matchedTransactions: sipTxns,
      );
    }

    // 4. Electricity & Utility Bill Queries
    if (q.contains('electricity') || q.contains('bescom') || q.contains('bill') || q.contains('utility') || q.contains('airtel')) {
      final billTxns = transactions.where((t) =>
          t.categoryName == 'Bills & Utilities' ||
          t.cleanMerchantName.toLowerCase().contains('bescom') ||
          t.cleanMerchantName.toLowerCase().contains('electricity') ||
          t.cleanMerchantName.toLowerCase().contains('billdesk') ||
          t.cleanMerchantName.toLowerCase().contains('airtel')).toList();

      if (billTxns.isEmpty) {
        return const QueryResult(answer: 'No utility or bill payments found.');
      }

      final total = billTxns.fold<int>(0, (sum, t) => sum + t.amount) / 100.0;
      return QueryResult(
        answer: 'Your utility bill payments total ${_inr.format(total)} across ${billTxns.length} bills.',
        totalAmount: total,
        matchedTransactions: billTxns,
      );
    }

    // 5. UPI Queries
    if (q.contains('upi')) {
      final upiTxns = transactions.where((t) =>
          t.rawDescription.toUpperCase().contains('UPI') ||
          t.cleanMerchantName.toUpperCase().contains('UPI')).toList();

      if (upiTxns.isEmpty) {
        return const QueryResult(answer: 'No UPI transactions found.');
      }

      final total = upiTxns.fold<int>(0, (sum, t) => sum + t.amount) / 100.0;
      return QueryResult(
        answer: 'Found ${upiTxns.length} UPI transactions totaling ${_inr.format(total)}.',
        totalAmount: total,
        matchedTransactions: upiTxns,
      );
    }

    // 6. Total Savings / Cashflow Queries
    if (q.contains('saving') || q.contains('cashflow') || q.contains('balance') || q.contains('net')) {
      final income = transactions.where((t) => t.isCredit).fold<int>(0, (sum, t) => sum + t.amount) / 100.0;
      final expense = transactions.where((t) => t.isDebit).fold<int>(0, (sum, t) => sum + t.amount) / 100.0;
      final net = income - expense;
      final rate = income > 0 ? (net / income) * 100.0 : 0.0;

      return QueryResult(
        answer: 'Your net cashflow is ${_inr.format(net)} with an overall savings rate of ${rate.toStringAsFixed(1)}% (Total Income: ${_inr.format(income)}, Total Expense: ${_inr.format(expense)}).',
        totalAmount: net,
        matchedTransactions: transactions,
      );
    }

    // 7. General search fallback across merchant/category
    final matches = transactions.where((t) =>
        t.cleanMerchantName.toLowerCase().contains(q) ||
        t.categoryName.toLowerCase().contains(q) ||
        t.rawDescription.toLowerCase().contains(q)).toList();

    if (matches.isNotEmpty) {
      final total = matches.fold<int>(0, (sum, t) => sum + t.amount) / 100.0;
      return QueryResult(
        answer: 'Found ${matches.length} transactions matching "$query" totaling ${_inr.format(total)}.',
        totalAmount: total,
        matchedTransactions: matches,
      );
    }

    return QueryResult(
      answer: 'I couldn\'t find any transactions related to "$query". Try asking about salary, dining, SIPs, or utility bills.',
    );
  }
}


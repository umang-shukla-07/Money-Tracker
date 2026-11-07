import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import '../models/transaction_model.dart';
import 'categorizer.dart';

enum BankFormat { hdfc, sbi, icici, axis, generic }

class IndianNumberParser {
  /// Converts Indian formatted numbers like "2,15,000.50", "₹1,45,210.00", "25000", "(500.00)"
  /// into exact integer paise (e.g. 21500050). Returns null if empty or non-numeric.
  static int? parseToPaise(dynamic raw) {
    if (raw == null) return null;
    String str = raw.toString().trim();
    if (str.isEmpty || str == '-' || str == '—') return null;

    // Detect negative indicators like (500) or -500
    bool isNegative = false;
    if (str.startsWith('(') && str.endsWith(')')) {
      isNegative = true;
      str = str.substring(1, str.length - 1);
    } else if (str.startsWith('-')) {
      isNegative = true;
      str = str.substring(1);
    }

    // Strip currency symbols, commas, spaces, Dr/Cr suffixes
    str = str
        .replaceAll('₹', '')
        .replaceAll('Rs.', '')
        .replaceAll('Rs', '')
        .replaceAll('INR', '')
        .replaceAll('Dr', '')
        .replaceAll('Cr', '')
        .replaceAll(',', '')
        .trim();

    if (str.isEmpty) return null;

    final doubleVal = double.tryParse(str);
    if (doubleVal == null) return null;

    final paise = (doubleVal * 100.0).round();
    return isNegative ? -paise : paise;
  }
}

class IndianDateParser {
  /// Parses DD/MM/YYYY, DD-MM-YYYY, DD/MM/YY, DD-Mon-YYYY (e.g. 01-Oct-2024), YYYY-MM-DD
  /// into standardized ISO 'YYYY-MM-DD'. Returns null if parsing fails.
  static String? parseToIso(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;

    // Already ISO YYYY-MM-DD
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(str)) {
      return str;
    }

    // DD/MM/YYYY or DD-MM-YYYY
    final ddmmyyyyMatch = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(str);
    if (ddmmyyyyMatch != null) {
      final day = ddmmyyyyMatch.group(1)!.padLeft(2, '0');
      final month = ddmmyyyyMatch.group(2)!.padLeft(2, '0');
      final year = ddmmyyyyMatch.group(3)!;
      return '$year-$month-$day';
    }

    // DD/MM/YY
    final ddmmyyMatch = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2})$').firstMatch(str);
    if (ddmmyyMatch != null) {
      final day = ddmmyyMatch.group(1)!.padLeft(2, '0');
      final month = ddmmyyMatch.group(2)!.padLeft(2, '0');
      final yy = int.parse(ddmmyyMatch.group(3)!);
      final year = (yy < 50 ? 2000 + yy : 1900 + yy).toString();
      return '$year-$month-$day';
    }

    // DD-Mon-YYYY or DD-Mon-YY (e.g. 15-Sep-2024, 01-OCT-24, 15/Sep/2024)
    final monMap = {
      'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04',
      'may': '05', 'jun': '06', 'jul': '07', 'aug': '08',
      'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12',
    };
    final ddMonMatch = RegExp(r'^(\d{1,2})[/-]([A-Za-z]{3})[/-](\d{2,4})$').firstMatch(str);
    if (ddMonMatch != null) {
      final day = ddMonMatch.group(1)!.padLeft(2, '0');
      final monStr = ddMonMatch.group(2)!.toLowerCase();
      final month = monMap[monStr];
      if (month != null) {
        var yearStr = ddMonMatch.group(3)!;
        if (yearStr.length == 2) {
          final yy = int.parse(yearStr);
          yearStr = (yy < 50 ? 2000 + yy : 1900 + yy).toString();
        }
        return '$yearStr-$month-$day';
      }
    }

    return null;
  }
}

class MerchantExtractor {
  /// Extracts a human-readable clean merchant name from raw Indian bank narrations.
  static String extractCleanMerchant(String rawNarration) {
    if (rawNarration.trim().isEmpty) return 'Unknown Merchant';
    final raw = rawNarration.trim();

    // 1. UPI: UPI/<ref>/<Merchant>/<vpa>/<note> or UPI/CR/<ref>/<Merchant>/<bank>/<note>
    if (raw.toUpperCase().startsWith('UPI')) {
      final parts = raw.split('/');
      if (parts.length >= 4) {
        if (parts[1].toUpperCase() == 'CR' || parts[1].toUpperCase() == 'DR') {
          if (parts.length >= 5 && parts[3].trim().isNotEmpty) {
            return _titleCase(parts[3].trim());
          }
        } else if (parts[2].trim().isNotEmpty) {
          return _titleCase(parts[2].trim());
        }
      }
    }

    // 2. POS: POS 421456XXXXXX1234 STARBUCKS BANGALORE IN
    final posMatch = RegExp(r'POS\s+[\dX*]+\s+(.+?)(?:\s+IN|\s+BLR|\s+MUM|\s+DEL)?$', caseSensitive: false).firstMatch(raw);
    if (posMatch != null) {
      final cleaned = posMatch.group(1)!.trim();
      if (cleaned.isNotEmpty) return _titleCase(cleaned);
    }

    // 3. ACH: ACH Dr-ZERODHA BROKING-MUTUAL FUND SIP 12345
    if (raw.toUpperCase().startsWith('ACH')) {
      var s = raw.replaceAll(RegExp(r'^ACH\s*(?:Dr|Cr)?[-:]\s*', caseSensitive: false), '');
      s = s.replaceAll(RegExp(r'\s*\d{4,}$'), '').trim();
      if (s.isNotEmpty) return _titleCase(s);
    }

    // 4. NEFT: NEFT-CR-AXIS000123-AMIT SHARMA-REFUND
    if (raw.toUpperCase().startsWith('NEFT')) {
      final parts = raw.split('-');
      if (parts.length >= 4) {
        return _titleCase(parts[3].trim());
      }
    }

    // 5. IMPS: IMPS/P2A/429102918/RAHUL VERMA/HDFC or IMPS-428192-MERCHANT
    if (raw.toUpperCase().startsWith('IMPS')) {
      final slashParts = raw.split('/');
      if (slashParts.length >= 4 && slashParts[3].trim().isNotEmpty) {
        return _titleCase(slashParts[3].trim());
      }
      final dashParts = raw.split('-');
      if (dashParts.length >= 3 && dashParts[2].trim().isNotEmpty) {
        return _titleCase(dashParts[2].trim());
      }
    }

    // 6. ATM: ATM-WDL-HDFC-INDIRANAGAR
    if (raw.toUpperCase().startsWith('ATM')) {
      var s = raw.replaceAll(RegExp(r'^ATM[-_\s]*(?:WDL|CWDR)?[-_\s]*', caseSensitive: false), '');
      return _titleCase('ATM ${s.replaceAll(RegExp(r'[-_]'), ' ')}');
    }

    // 7. BILLDESK: BILLDESK*BESCOM*ELECTRICITY 492019
    if (raw.toUpperCase().startsWith('BILLDESK')) {
      final parts = raw.split('*');
      if (parts.length >= 2) {
        var s = parts.sublist(1).join(' ').replaceAll(RegExp(r'\s*\d{4,}$'), '');
        return _titleCase(s);
      }
    }

    // 8. SALARY CREDIT: SALARY CREDIT - OCT 2024 - GOOGLE INDIA PVT LTD
    if (raw.toUpperCase().contains('SALARY')) {
      final parts = raw.split('-');
      if (parts.length >= 3) {
        return _titleCase(parts.last.trim());
      }
    }

    // 9. ECOM: ECOM/AMAZON PAY INDIA/421456XXXXXX1234
    if (raw.toUpperCase().startsWith('ECOM')) {
      final parts = raw.split('/');
      if (parts.length >= 2) {
        return _titleCase(parts[1].trim());
      }
    }

    // Fallback: cleanup special characters and return
    return _titleCase(raw.replaceAll(RegExp(r'[*_\-/]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim());
  }

  static String _titleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').where((w) => w.isNotEmpty).map((word) {
      if (word.length <= 1) return word.toUpperCase();
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}

class DeduplicationService {
  /// Generates a deterministic SHA-256 hash for deduplication.
  static String generateHash({
    required String date,
    required int amount,
    required String cleanMerchantName,
    int? balance,
    String? rawDescription,
  }) {
    final payload = '$date|$amount|$cleanMerchantName|${balance ?? ''}|${rawDescription ?? ''}';
    return sha256.convert(utf8.encode(payload)).toString();
  }
}

class StatementParserService {
  /// Detects the bank format from CSV header rows.
  static BankFormat detectFormat(List<String> headers) {
    final lowerHeaders = headers.map((h) => h.trim().toLowerCase()).toList();

    if (lowerHeaders.any((h) => h.contains('narration')) &&
        lowerHeaders.any((h) => h.contains('withdrawal') || h.contains('deposit'))) {
      return BankFormat.hdfc;
    }
    if (lowerHeaders.any((h) => h.contains('txn date') || h.contains('value date')) &&
        lowerHeaders.any((h) => h.contains('debit') || h.contains('credit'))) {
      return BankFormat.sbi;
    }
    if (lowerHeaders.any((h) => h.contains('transaction remarks')) &&
        lowerHeaders.any((h) => h.contains('withdrawal amount') || h.contains('deposit amount'))) {
      return BankFormat.icici;
    }
    if (lowerHeaders.any((h) => h.contains('particulars')) &&
        lowerHeaders.any((h) => h.contains('tran date') || h.contains('chq no'))) {
      return BankFormat.axis;
    }

    return BankFormat.generic;
  }

  /// Parses CSV text using the specified or auto-detected bank adapter.
  static List<TransactionModel> parseCsv(String csvContent, {BankFormat? forceFormat}) {
    if (csvContent.trim().isEmpty) return [];

    final normalized = _normalizeUnquotedNumbers(csvContent);
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(normalized);
    if (rows.isEmpty) return [];

    // Find header row (the first row with at least 3 non-empty string cells)
    int headerIndex = -1;
    List<String> headers = [];

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i].map((c) => c.toString().trim()).toList();
      final nonEmpty = row.where((c) => c.isNotEmpty).length;
      if (nonEmpty >= 3) {
        headerIndex = i;
        headers = row;
        break;
      }
    }

    if (headerIndex == -1 || headers.isEmpty) return [];

    final format = forceFormat ?? detectFormat(headers);
    final transactions = <TransactionModel>[];

    for (int r = headerIndex + 1; r < rows.length; r++) {
      final row = rows[r].map((c) => c.toString().trim()).toList();
      if (row.length < 3 || row.every((c) => c.isEmpty)) continue;

      final txn = _parseRow(row, headers, format);
      if (txn != null) {
        transactions.add(txn);
      }
    }

    return transactions;
  }

  static TransactionModel? _parseRow(List<String> row, List<String> headers, BankFormat format) {
    String? rawDate;
    String rawDesc = '';
    int? debitPaise;
    int? creditPaise;
    int? balancePaise;

    switch (format) {
      case BankFormat.hdfc:
        // Date,Narration,Chq./Ref.No.,Value Dt,Withdrawal Amt.,Deposit Amt.,Closing Balance
        rawDate = _getCell(row, headers, ['date', 'txn date']);
        rawDesc = _getCell(row, headers, ['narration', 'description']) ?? '';
        debitPaise = IndianNumberParser.parseToPaise(_getCell(row, headers, ['withdrawal amt.', 'withdrawal amt', 'debit']));
        creditPaise = IndianNumberParser.parseToPaise(_getCell(row, headers, ['deposit amt.', 'deposit amt', 'credit']));
        balancePaise = IndianNumberParser.parseToPaise(_getCell(row, headers, ['closing balance', 'balance']));
        break;

      case BankFormat.sbi:
        // Txn Date,Value Date,Description,Ref No./Cheque No.,Debit,Credit,Balance
        rawDate = _getCell(row, headers, ['txn date', 'date']);
        rawDesc = _getCell(row, headers, ['description', 'narration']) ?? '';
        debitPaise = IndianNumberParser.parseToPaise(_getCell(row, headers, ['debit']));
        creditPaise = IndianNumberParser.parseToPaise(_getCell(row, headers, ['credit']));
        balancePaise = IndianNumberParser.parseToPaise(_getCell(row, headers, ['balance']));
        break;

      case BankFormat.icici:
        // Transaction Date,Transaction Remarks,Withdrawal Amount (INR ),Deposit Amount (INR ),Balance (INR )
        rawDate = _getCell(row, headers, ['transaction date', 'date']);
        rawDesc = _getCell(row, headers, ['transaction remarks', 'remarks', 'description']) ?? '';
        debitPaise = IndianNumberParser.parseToPaise(_getCell(row, headers, ['withdrawal amount', 'debit']));
        creditPaise = IndianNumberParser.parseToPaise(_getCell(row, headers, ['deposit amount', 'credit']));
        balancePaise = IndianNumberParser.parseToPaise(_getCell(row, headers, ['balance']));
        break;

      case BankFormat.axis:
        // Tran Date,Particulars,Debit,Credit,Balance
        rawDate = _getCell(row, headers, ['tran date', 'date']);
        rawDesc = _getCell(row, headers, ['particulars', 'narration', 'description']) ?? '';
        debitPaise = IndianNumberParser.parseToPaise(_getCell(row, headers, ['debit']));
        creditPaise = IndianNumberParser.parseToPaise(_getCell(row, headers, ['credit']));
        balancePaise = IndianNumberParser.parseToPaise(_getCell(row, headers, ['balance']));
        break;

      case BankFormat.generic:
        rawDate = _getCell(row, headers, ['transaction_date', 'txn_date', 'date', 'txn date']);
        rawDesc = _getCell(row, headers, ['details', 'description', 'narration', 'particulars', 'remarks']) ?? '';
        debitPaise = IndianNumberParser.parseToPaise(_getCell(row, headers, ['spent', 'debit', 'withdrawal', 'outflow']));
        creditPaise = IndianNumberParser.parseToPaise(_getCell(row, headers, ['received', 'credit', 'deposit', 'inflow']));
        balancePaise = IndianNumberParser.parseToPaise(_getCell(row, headers, ['account_balance', 'closing balance', 'balance']));
        break;
    }

    final isoDate = IndianDateParser.parseToIso(rawDate);
    if (isoDate == null) return null;

    final isCredit = (creditPaise != null && creditPaise > 0);
    final isDebit = (debitPaise != null && debitPaise > 0);
    if (!isCredit && !isDebit) return null;

    final amount = isCredit ? creditPaise : debitPaise!;
    final direction = isCredit ? 'credit' : 'debit';
    final cleanMerchant = MerchantExtractor.extractCleanMerchant(rawDesc);

    // Run 3-stage Categorization
    final catResult = CategorizerService.categorize(
      cleanMerchant: cleanMerchant,
      rawDescription: rawDesc,
      direction: direction,
    );

    final hash = DeduplicationService.generateHash(
      date: isoDate,
      amount: amount,
      cleanMerchantName: cleanMerchant,
      balance: balancePaise,
      rawDescription: rawDesc,
    );

    return TransactionModel(
      id: 'tx_${hash.substring(0, 12)}',
      date: isoDate,
      amount: amount,
      direction: direction,
      rawDescription: rawDesc,
      cleanMerchantName: cleanMerchant,
      categoryId: catResult.categoryId,
      categoryName: catResult.categoryName,
      confidence: catResult.confidence,
      reviewStatus: catResult.reviewStatus,
      hash: hash,
      balance: balancePaise,
      bankFormat: format.name.toUpperCase(),
    );
  }

  static String? _getCell(List<String> row, List<String> headers, List<String> potentialMatches) {
    for (int col = 0; col < headers.length; col++) {
      final headerName = headers[col].toLowerCase().trim();
      for (final match in potentialMatches) {
        if (headerName.contains(match.toLowerCase())) {
          if (col < row.length) {
            final val = row[col].trim();
            if (val.isNotEmpty) return val;
          }
        }
      }
    }
    return null;
  }

  static String _normalizeUnquotedNumbers(String input) {
    final lines = input.split('\n');
    final numRegex = RegExp(r'(?<=,|^)(\d{1,2}(?:,\d{2})*,\d{3}(?:\.\d{2})?)(?=,|$)');

    return lines.map((line) {
      if (line.contains('"')) return line;
      return line.replaceAllMapped(numRegex, (m) => '"${m.group(1)}"');
    }).join('\n');
  }
}

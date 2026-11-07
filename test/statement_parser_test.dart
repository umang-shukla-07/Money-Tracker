import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlens/services/statement_parser.dart';

void main() {
  group('IndianNumberParser Tests', () {
    test('parses Indian number format with commas and decimals', () {
      expect(IndianNumberParser.parseToPaise('2,15,000.50'), equals(21500050));
      expect(IndianNumberParser.parseToPaise('1,45,210.00'), equals(14521000));
      expect(IndianNumberParser.parseToPaise('12,500.00'), equals(1250000));
      expect(IndianNumberParser.parseToPaise('1,00,00,000'), equals(1000000000));
    });

    test('strips Indian rupee symbols, Rs, INR, and Dr/Cr suffixes', () {
      expect(IndianNumberParser.parseToPaise('₹25,000.00'), equals(2500000));
      expect(IndianNumberParser.parseToPaise('Rs. 642.50'), equals(64250));
      expect(IndianNumberParser.parseToPaise('500.00 Cr'), equals(50000));
      expect(IndianNumberParser.parseToPaise('1200.00 Dr'), equals(120000));
    });

    test('handles negative amounts and bracketed debits', () {
      expect(IndianNumberParser.parseToPaise('(500.00)'), equals(-50000));
      expect(IndianNumberParser.parseToPaise('-1,250.75'), equals(-125075));
    });

    test('returns null for empty, dashes, and invalid inputs', () {
      expect(IndianNumberParser.parseToPaise(''), isNull);
      expect(IndianNumberParser.parseToPaise('-'), isNull);
      expect(IndianNumberParser.parseToPaise('—'), isNull);
      expect(IndianNumberParser.parseToPaise('N/A'), isNull);
      expect(IndianNumberParser.parseToPaise(null), isNull);
    });
  });

  group('IndianDateParser Tests', () {
    test('parses DD/MM/YYYY and DD-MM-YYYY to ISO YYYY-MM-DD', () {
      expect(IndianDateParser.parseToIso('01/10/2024'), equals('2024-10-01'));
      expect(IndianDateParser.parseToIso('15-09-2024'), equals('2024-09-15'));
      expect(IndianDateParser.parseToIso('4/5/2024'), equals('2024-05-04'));
    });

    test('parses 2-digit year format DD/MM/YY', () {
      expect(IndianDateParser.parseToIso('01/10/24'), equals('2024-10-01'));
      expect(IndianDateParser.parseToIso('15/09/24'), equals('2024-09-15'));
    });

    test('parses DD-Mon-YYYY and DD-Mon-YY text formats', () {
      expect(IndianDateParser.parseToIso('01-Oct-2024'), equals('2024-10-01'));
      expect(IndianDateParser.parseToIso('15-Sep-24'), equals('2024-09-15'));
      expect(IndianDateParser.parseToIso('05/Nov/2024'), equals('2024-11-05'));
    });

    test('preserves existing ISO YYYY-MM-DD format', () {
      expect(IndianDateParser.parseToIso('2024-10-01'), equals('2024-10-01'));
    });

    test('returns null for invalid date formats', () {
      expect(IndianDateParser.parseToIso(''), isNull);
      expect(IndianDateParser.parseToIso('invalid-date'), isNull);
      expect(IndianDateParser.parseToIso(null), isNull);
    });
  });

  group('MerchantExtractor Tests', () {
    test('extracts clean merchant from standard UPI string', () {
      final raw = 'UPI/428381928391/Swiggy/swiggy@icici/Order 92831';
      expect(MerchantExtractor.extractCleanMerchant(raw), equals('Swiggy'));
    });

    test('extracts clean merchant from UPI with CR/DR prefix', () {
      final raw = 'UPI/CR/429102918291/Zomato Ltd/HDFC/Dinner';
      expect(MerchantExtractor.extractCleanMerchant(raw), equals('Zomato Ltd'));
    });

    test('extracts clean merchant from POS card swipe narrations', () {
      final raw = 'POS 421456XXXXXX1234 STARBUCKS BANGALORE IN';
      expect(MerchantExtractor.extractCleanMerchant(raw), equals('Starbucks Bangalore'));
    });

    test('extracts clean merchant from ACH / SIP mandates', () {
      final raw = 'ACH Dr-ZERODHA BROKING-MUTUAL FUND SIP 12345';
      expect(MerchantExtractor.extractCleanMerchant(raw), equals('Zerodha Broking-mutual Fund Sip'));
    });

    test('extracts clean recipient/sender from NEFT transfers', () {
      final raw = 'NEFT-CR-AXIS000123-AMIT SHARMA-REFUND';
      expect(MerchantExtractor.extractCleanMerchant(raw), equals('Amit Sharma'));
    });

    test('extracts clean merchant from IMPS transfers', () {
      final raw = 'IMPS/P2A/429102918/RAHUL VERMA/HDFC';
      expect(MerchantExtractor.extractCleanMerchant(raw), equals('Rahul Verma'));
    });

    test('extracts clean location from ATM withdrawals', () {
      final raw = 'ATM-WDL-HDFC-INDIRANAGAR';
      expect(MerchantExtractor.extractCleanMerchant(raw), equals('Atm Hdfc Indiranagar'));
    });

    test('extracts clean utility from BillDesk narration', () {
      final raw = 'BILLDESK*BESCOM*ELECTRICITY 492019';
      expect(MerchantExtractor.extractCleanMerchant(raw), equals('Bescom Electricity'));
    });

    test('extracts employer from Salary narration', () {
      final raw = 'SALARY CREDIT - OCT 2024 - GOOGLE INDIA PVT LTD';
      expect(MerchantExtractor.extractCleanMerchant(raw), equals('Google India Pvt Ltd'));
    });
  });

  group('DeduplicationService Tests', () {
    test('generates deterministic SHA-256 hash', () {
      final hash1 = DeduplicationService.generateHash(
        date: '2024-10-01',
        amount: 21500000,
        cleanMerchantName: 'Google India Pvt Ltd',
        balance: 28540050,
      );
      final hash2 = DeduplicationService.generateHash(
        date: '2024-10-01',
        amount: 21500000,
        cleanMerchantName: 'Google India Pvt Ltd',
        balance: 28540050,
      );
      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64));
    });

    test('generates different hashes for different amounts or dates', () {
      final hash1 = DeduplicationService.generateHash(
        date: '2024-10-01',
        amount: 21500000,
        cleanMerchantName: 'Google India Pvt Ltd',
      );
      final hash2 = DeduplicationService.generateHash(
        date: '2024-10-02',
        amount: 21500000,
        cleanMerchantName: 'Google India Pvt Ltd',
      );
      expect(hash1, isNot(equals(hash2)));
    });
  });

  group('Bank Adapters Parsing Tests', () {
    test('HDFC Bank adapter parses HDFC statement CSV correctly', () {
      const hdfcCsv = '''Date,Narration,Chq./Ref.No.,Value Dt,Withdrawal Amt.,Deposit Amt.,Closing Balance
01/10/24,SALARY CREDIT - OCT 2024 - GOOGLE INDIA PVT LTD,0001001,01/10/24,,215000.00,285400.50
02/10/24,ACH Dr-ZERODHA BROKING-MUTUAL FUND SIP 12345,ACH892182,02/10/24,25000.00,,260400.50
03/10/24,UPI/428381928391/Swiggy/swiggy@icici/Order 92831,428381928391,03/10/24,642.50,,259758.00''';

      final txns = StatementParserService.parseCsv(hdfcCsv);
      expect(txns.length, equals(3));

      // 1. Google Salary
      expect(txns[0].date, equals('2024-10-01'));
      expect(txns[0].amount, equals(21500000));
      expect(txns[0].direction, equals('credit'));
      expect(txns[0].cleanMerchantName, equals('Google India Pvt Ltd'));
      expect(txns[0].categoryName, equals('Salary & Income'));

      // 2. Zerodha SIP
      expect(txns[1].date, equals('2024-10-02'));
      expect(txns[1].amount, equals(2500000));
      expect(txns[1].direction, equals('debit'));
      expect(txns[1].categoryName, equals('Investments & SIP'));

      // 3. Swiggy
      expect(txns[2].date, equals('2024-10-03'));
      expect(txns[2].amount, equals(64250));
      expect(txns[2].direction, equals('debit'));
      expect(txns[2].cleanMerchantName, equals('Swiggy'));
      expect(txns[2].categoryName, equals('Food & Dining'));
    });

    test('SBI Bank adapter parses SBI statement CSV correctly', () {
      const sbiCsv = '''Txn Date,Value Date,Description,Ref No./Cheque No.,Debit,Credit,Balance
15-09-2024,15-09-2024,UPI/CR/429102918291/Zomato Ltd/HDFC/Dinner,429102918291,890.00,,1,45,210.00
16-09-2024,16-09-2024,ACH Dr-HDFC LIFE-INSURANCE PREMIUM,ACH918273,12,500.00,,1,32,710.00
18-09-2024,18-09-2024,INT.PD:01-07-2024 to 30-09-2024,INT99281,,1,420.00,1,32,952.00''';

      final txns = StatementParserService.parseCsv(sbiCsv);
      expect(txns.length, equals(3));

      expect(txns[0].date, equals('2024-09-15'));
      expect(txns[0].amount, equals(89000));
      expect(txns[0].direction, equals('debit'));
      expect(txns[0].cleanMerchantName, equals('Zomato Ltd'));

      expect(txns[2].date, equals('2024-09-18'));
      expect(txns[2].amount, equals(142000));
      expect(txns[2].direction, equals('credit'));
      expect(txns[2].categoryName, equals('Salary & Income'));
    });

    test('ICICI Bank adapter parses ICICI statement CSV correctly', () {
      const iciciCsv = '''Transaction Date,Transaction Remarks,Withdrawal Amount (INR ),Deposit Amount (INR ),Balance (INR )
04/10/2024,POS 421456XXXXXX1234 STARBUCKS BANGALORE IN,420.00,,259338.00
08/10/2024,PAYU*NETFLIX*ENTERTAINMENT,649.00,,250459.00''';

      final txns = StatementParserService.parseCsv(iciciCsv);
      expect(txns.length, equals(2));

      expect(txns[0].date, equals('2024-10-04'));
      expect(txns[0].amount, equals(42000));
      expect(txns[0].cleanMerchantName, equals('Starbucks Bangalore'));
      expect(txns[0].categoryName, equals('Food & Dining'));

      expect(txns[1].date, equals('2024-10-08'));
      expect(txns[1].amount, equals(64900));
      expect(txns[1].categoryName, equals('Entertainment'));
    });

    test('Axis Bank adapter parses Axis statement CSV correctly', () {
      const axisCsv = '''Tran Date,Particulars,Debit,Credit,Balance
05-10-2024,BILLDESK*BESCOM*ELECTRICITY 492019,2850.00,,256488.00
07-10-2024,UPI/428491829102/Uber/uber@axis/Trip 8192,380.00,,251108.00''';

      final txns = StatementParserService.parseCsv(axisCsv);
      expect(txns.length, equals(2));

      expect(txns[0].date, equals('2024-10-05'));
      expect(txns[0].amount, equals(285000));
      expect(txns[0].categoryName, equals('Bills & Utilities'));

      expect(txns[1].date, equals('2024-10-07'));
      expect(txns[1].amount, equals(38000));
      expect(txns[1].categoryName, equals('Transport & Fuel'));
    });

    test('Generic Bank adapter parses custom column mapped CSV', () {
      const genericCsv = '''Transaction_Date,Details,Spent,Received,Account_Balance
2024-08-10,Cult.fit Annual Membership Renewal,14999.00,,95000.00
2024-08-12,Freelance Consulting UI Design,,45000.00,140000.00''';

      final txns = StatementParserService.parseCsv(genericCsv);
      expect(txns.length, equals(2));

      expect(txns[0].date, equals('2024-08-10'));
      expect(txns[0].amount, equals(1499900));
      expect(txns[0].direction, equals('debit'));

      expect(txns[1].date, equals('2024-08-12'));
      expect(txns[1].amount, equals(4500000));
      expect(txns[1].direction, equals('credit'));
      expect(txns[1].categoryName, equals('Salary & Income'));
    });
  });
}

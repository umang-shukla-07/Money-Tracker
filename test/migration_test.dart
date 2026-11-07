import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ledgerlens/models/transaction_model.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Database v1 to v2 Migration & User Isolation Tests', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      // Construct v1 schema
      await db.execute('''
        CREATE TABLE transactions (
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL,
          amount INTEGER NOT NULL,
          direction TEXT NOT NULL,
          raw_description TEXT NOT NULL,
          clean_merchant_name TEXT NOT NULL,
          category_name TEXT NOT NULL,
          category_id TEXT,
          confidence REAL NOT NULL,
          review_status TEXT NOT NULL,
          hash TEXT NOT NULL,
          balance INTEGER,
          bank_format TEXT,
          notes TEXT
        );
      ''');

      await db.execute('''
        CREATE TABLE categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          icon TEXT NOT NULL,
          color TEXT NOT NULL,
          is_system INTEGER NOT NULL DEFAULT 0,
          description TEXT
        );
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('v1 to v2 migration preserves existing transactions and adds user_id, updated_at, deleted', () async {
      // 1. Seed existing transactions in v1
      await db.insert('transactions', {
        'id': 'txn_v1_001',
        'date': '2026-10-15',
        'amount': 45000,
        'direction': 'debit',
        'raw_description': 'UPI/SWIGGY/123456/PAYMENT',
        'clean_merchant_name': 'Swiggy',
        'category_name': 'Food & Dining',
        'confidence': 0.98,
        'review_status': 'confirmed',
        'hash': 'hash_v1_swiggy',
        'balance': 2500000,
        'bank_format': 'HDFC',
        'notes': 'Dinner order',
      });

      await db.insert('transactions', {
        'id': 'txn_v1_002',
        'date': '2026-10-16',
        'amount': 1200000,
        'direction': 'credit',
        'raw_description': 'NEFT/SALARY/OCTOBER',
        'clean_merchant_name': 'Employer Payroll',
        'category_name': 'Salary & Income',
        'confidence': 0.99,
        'review_status': 'confirmed',
        'hash': 'hash_v1_salary',
        'balance': 3700000,
        'bank_format': 'HDFC',
      });

      // 2. Perform v2 upgrade migration
      await db.execute('ALTER TABLE transactions ADD COLUMN user_id TEXT;');
      await db.execute('ALTER TABLE transactions ADD COLUMN updated_at TEXT;');
      await db.execute('ALTER TABLE transactions ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0;');
      await db.execute("UPDATE transactions SET updated_at = date || 'T00:00:00.000Z', deleted = 0 WHERE updated_at IS NULL;");
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_meta (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );
      ''');

      // 3. Verify data preservation
      final rows = await db.query('transactions', orderBy: 'date ASC');
      expect(rows.length, 2);

      final first = rows[0];
      expect(first['id'], 'txn_v1_001');
      expect(first['clean_merchant_name'], 'Swiggy');
      expect(first['amount'], 45000);
      expect(first['deleted'], 0);
      expect(first['updated_at'], '2026-10-15T00:00:00.000Z');
      expect(first['user_id'], isNull);

      final second = rows[1];
      expect(second['id'], 'txn_v1_002');
      expect(second['clean_merchant_name'], 'Employer Payroll');
      expect(second['amount'], 1200000);
      expect(second['deleted'], 0);
      expect(second['updated_at'], '2026-10-16T00:00:00.000Z');
      expect(second['user_id'], isNull);
    });

    test('Stamping user_id on unassigned rows preserves existing data and marks for sync', () async {
      // Seed v2 schema with unassigned rows (e.g. offline guest mode)
      await db.execute('ALTER TABLE transactions ADD COLUMN user_id TEXT;');
      await db.execute('ALTER TABLE transactions ADD COLUMN updated_at TEXT;');
      await db.execute('ALTER TABLE transactions ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0;');

      await db.insert('transactions', {
        'id': 'txn_offline_1',
        'date': '2026-10-20',
        'amount': 32000,
        'direction': 'debit',
        'raw_description': 'BLINKIT/GROCERIES',
        'clean_merchant_name': 'Blinkit',
        'category_name': 'Groceries',
        'confidence': 0.95,
        'review_status': 'confirmed',
        'hash': 'hash_blinkit_1',
        'deleted': 0,
        'updated_at': '2026-10-20T10:00:00.000Z',
      });

      const siblingA = 'user_sibling_alpha_111';
      final stampTime = DateTime.now().toUtc().toIso8601String();

      // Stamp user_id on unassigned local transactions
      await db.update(
        'transactions',
        {
          'user_id': siblingA,
          'updated_at': stampTime,
        },
        where: 'user_id IS NULL OR user_id = ""',
      );

      final rows = await db.query('transactions', where: 'id = ?', whereArgs: ['txn_offline_1']);
      expect(rows.first['user_id'], siblingA);
      expect(rows.first['clean_merchant_name'], 'Blinkit');
      expect(rows.first['amount'], 32000);
      expect(rows.first['updated_at'], stampTime);
    });

    test('Multi-user isolation: User A queries never return User B transactions', () async {
      // Setup v2 schema
      await db.execute('ALTER TABLE transactions ADD COLUMN user_id TEXT;');
      await db.execute('ALTER TABLE transactions ADD COLUMN updated_at TEXT;');
      await db.execute('ALTER TABLE transactions ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0;');

      const siblingA = 'sibling_alpha_uuid';
      const siblingB = 'sibling_beta_uuid';

      // Insert User A transactions
      final txnA1 = TransactionModel(
        id: 'txn_a_1',
        date: '2026-10-01',
        amount: 50000,
        direction: 'debit',
        rawDescription: 'AMZN/ALPHA',
        cleanMerchantName: 'Amazon Alpha',
        categoryName: 'Shopping',
        confidence: 0.95,
        reviewStatus: 'confirmed',
        hash: 'hash_a_1',
        userId: siblingA,
        updatedAt: '2026-10-01T12:00:00.000Z',
      );
      final txnA2 = TransactionModel(
        id: 'txn_a_2',
        date: '2026-10-02',
        amount: 15000,
        direction: 'debit',
        rawDescription: 'SWIGGY/ALPHA',
        cleanMerchantName: 'Swiggy Alpha',
        categoryName: 'Food & Dining',
        confidence: 0.95,
        reviewStatus: 'confirmed',
        hash: 'hash_a_2',
        userId: siblingA,
        updatedAt: '2026-10-02T12:00:00.000Z',
      );

      // Insert User B transactions
      final txnB1 = TransactionModel(
        id: 'txn_b_1',
        date: '2026-10-01',
        amount: 80000,
        direction: 'debit',
        rawDescription: 'FLIPKART/BETA',
        cleanMerchantName: 'Flipkart Beta',
        categoryName: 'Shopping',
        confidence: 0.95,
        reviewStatus: 'confirmed',
        hash: 'hash_b_1',
        userId: siblingB,
        updatedAt: '2026-10-01T14:00:00.000Z',
      );

      await db.insert('transactions', txnA1.toMap());
      await db.insert('transactions', txnA2.toMap());
      await db.insert('transactions', txnB1.toMap());

      // Query User A
      final resultsA = await db.query(
        'transactions',
        where: 'deleted = 0 AND user_id = ?',
        whereArgs: [siblingA],
      );
      expect(resultsA.length, 2);
      expect(resultsA.every((r) => r['user_id'] == siblingA), isTrue);
      expect(resultsA.any((r) => r['id'] == 'txn_b_1'), isFalse);

      // Query User B
      final resultsB = await db.query(
        'transactions',
        where: 'deleted = 0 AND user_id = ?',
        whereArgs: [siblingB],
      );
      expect(resultsB.length, 1);
      expect(resultsB.first['id'], 'txn_b_1');
      expect(resultsB.first['user_id'], siblingB);
      expect(resultsB.any((r) => r['id'] == 'txn_a_1' || r['id'] == 'txn_a_2'), isFalse);
    });
  });
}


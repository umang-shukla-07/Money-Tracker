import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/transaction_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ledgerlens.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        date TEXT NOT NULL,
        amount INTEGER NOT NULL,
        direction TEXT NOT NULL,
        raw_description TEXT NOT NULL,
        clean_merchant_name TEXT NOT NULL,
        category_id TEXT,
        category_name TEXT NOT NULL,
        confidence REAL NOT NULL DEFAULT 1.0,
        review_status TEXT NOT NULL DEFAULT 'auto',
        hash TEXT NOT NULL UNIQUE,
        balance INTEGER,
        bank_format TEXT,
        notes TEXT,
        updated_at TEXT NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0
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

    await db.execute('''
      CREATE TABLE sync_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    // Seed Initial Transactions for offline trial
    await _seedInitialData(db);
  }

  Future<void> _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
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
    }
  }

  Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final sampleTxns = [
      TransactionModel(
        id: 'tx_01',
        date: '2024-10-01',
        amount: 21500000, // ₹2,15,000.00
        direction: 'credit',
        rawDescription: 'SALARY CREDIT - OCT 2024 - GOOGLE INDIA PVT LTD',
        cleanMerchantName: 'Google India Pvt Ltd',
        categoryName: 'Salary & Income',
        confidence: 0.99,
        reviewStatus: 'confirmed',
        hash: 'hash_google_salary_oct24',
        balance: 28540050,
        bankFormat: 'HDFC',
        updatedAt: now,
      ),
      TransactionModel(
        id: 'tx_02',
        date: '2024-10-02',
        amount: 2500000, // ₹25,000.00
        direction: 'debit',
        rawDescription: 'ACH Dr-ZERODHA BROKING-MUTUAL FUND SIP 12345',
        cleanMerchantName: 'Zerodha Mutual Fund SIP',
        categoryName: 'Investments & SIP',
        confidence: 0.98,
        reviewStatus: 'confirmed',
        hash: 'hash_zerodha_sip_oct24',
        balance: 26040050,
        bankFormat: 'HDFC',
        updatedAt: now,
      ),
      TransactionModel(
        id: 'tx_03',
        date: '2024-10-03',
        amount: 64250, // ₹642.50
        direction: 'debit',
        rawDescription: 'UPI/428381928391/Swiggy/swiggy@icici/Order 92831',
        cleanMerchantName: 'Swiggy',
        categoryName: 'Food & Dining',
        confidence: 0.95,
        reviewStatus: 'auto',
        hash: 'hash_swiggy_oct24',
        balance: 25975800,
        bankFormat: 'HDFC',
        updatedAt: now,
      ),
      TransactionModel(
        id: 'tx_04',
        date: '2024-10-04',
        amount: 42000, // ₹420.00
        direction: 'debit',
        rawDescription: 'POS 421456XXXXXX1234 STARBUCKS BANGALORE IN',
        cleanMerchantName: 'Starbucks Bangalore',
        categoryName: 'Food & Dining',
        confidence: 0.62,
        reviewStatus: 'needs_review',
        hash: 'hash_starbucks_oct24',
        balance: 25933800,
        bankFormat: 'HDFC',
        updatedAt: now,
      ),
      TransactionModel(
        id: 'tx_05',
        date: '2024-10-05',
        amount: 285000, // ₹2,850.00
        direction: 'debit',
        rawDescription: 'BILLDESK*BESCOM*ELECTRICITY 492019',
        cleanMerchantName: 'BESCOM Electricity Bill',
        categoryName: 'Bills & Utilities',
        confidence: 0.96,
        reviewStatus: 'confirmed',
        hash: 'hash_bescom_oct24',
        balance: 25648800,
        bankFormat: 'HDFC',
        updatedAt: now,
      ),
      TransactionModel(
        id: 'tx_06',
        date: '2024-10-06',
        amount: 500000, // ₹5,000.00
        direction: 'debit',
        rawDescription: 'ATM-WDL-HDFC-INDIRANAGAR',
        cleanMerchantName: 'ATM Cash Withdrawal',
        categoryName: 'Other',
        confidence: 0.88,
        reviewStatus: 'auto',
        hash: 'hash_atm_oct24',
        balance: 25148800,
        bankFormat: 'HDFC',
        updatedAt: now,
      ),
      TransactionModel(
        id: 'tx_07',
        date: '2024-10-07',
        amount: 38000, // ₹380.00
        direction: 'debit',
        rawDescription: 'UPI/428491829102/Uber/uber@axis/Trip 8192',
        cleanMerchantName: 'Uber',
        categoryName: 'Transport & Fuel',
        confidence: 0.94,
        reviewStatus: 'auto',
        hash: 'hash_uber_oct24',
        balance: 25110800,
        bankFormat: 'HDFC',
        updatedAt: now,
      ),
      TransactionModel(
        id: 'tx_08',
        date: '2024-10-08',
        amount: 64900, // ₹649.00
        direction: 'debit',
        rawDescription: 'PAYU*NETFLIX*ENTERTAINMENT',
        cleanMerchantName: 'Netflix',
        categoryName: 'Entertainment',
        confidence: 0.98,
        reviewStatus: 'confirmed',
        hash: 'hash_netflix_oct24',
        balance: 25045900,
        bankFormat: 'HDFC',
        updatedAt: now,
      ),
      TransactionModel(
        id: 'tx_09',
        date: '2024-10-09',
        amount: 124000, // ₹1,240.00
        direction: 'debit',
        rawDescription: 'UPI/429182910281/BLINKIT COMMERCE/PAYTM/Grocery',
        cleanMerchantName: 'Blinkit Commerce',
        categoryName: 'Food & Dining',
        confidence: 0.91,
        reviewStatus: 'auto',
        hash: 'hash_blinkit_oct24',
        balance: 24921900,
        bankFormat: 'HDFC',
        updatedAt: now,
      ),
      TransactionModel(
        id: 'tx_10',
        date: '2024-10-10',
        amount: 350000, // ₹3,500.00
        direction: 'credit',
        rawDescription: 'NEFT-CR-AXIS000123-AMIT SHARMA-REFUND',
        cleanMerchantName: 'Amit Sharma Refund',
        categoryName: 'Salary & Income',
        confidence: 0.54,
        reviewStatus: 'needs_review',
        hash: 'hash_refund_oct24',
        balance: 25271900,
        bankFormat: 'HDFC',
        updatedAt: now,
      ),
    ];

    for (final txn in sampleTxns) {
      await db.insert(
        'transactions',
        txn.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// Scopes queries to the authenticated user ID (or local unassigned rows if not logged in).
  Future<List<TransactionModel>> getAllTransactions({String? userId}) async {
    final db = await instance.database;
    final String where;
    final List<dynamic> whereArgs;

    if (userId != null && userId.isNotEmpty) {
      where = 'deleted = 0 AND (user_id = ? OR user_id IS NULL)';
      whereArgs = [userId];
    } else {
      where = 'deleted = 0 AND (user_id IS NULL OR user_id = "")';
      whereArgs = [];
    }

    final result = await db.query(
      'transactions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );
    return result.map((m) => TransactionModel.fromMap(m)).toList();
  }

  Future<List<TransactionModel>> getReviewQueue({String? userId}) async {
    final db = await instance.database;
    final String where;
    final List<dynamic> whereArgs;

    if (userId != null && userId.isNotEmpty) {
      where = 'review_status = ? AND deleted = 0 AND (user_id = ? OR user_id IS NULL)';
      whereArgs = ['needs_review', userId];
    } else {
      where = 'review_status = ? AND deleted = 0 AND (user_id IS NULL OR user_id = "")';
      whereArgs = ['needs_review'];
    }

    final result = await db.query(
      'transactions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );
    return result.map((m) => TransactionModel.fromMap(m)).toList();
  }

  Future<void> confirmReview(String id, {String? categoryName}) async {
    final db = await instance.database;
    final values = <String, dynamic>{
      'review_status': 'confirmed',
      'confidence': 1.0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (categoryName != null) {
      values['category_name'] = categoryName;
    }
    await db.update(
      'transactions',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertTransaction(TransactionModel txn, {String? userId}) async {
    final db = await instance.database;
    final toInsert = txn.copyWith(
      userId: userId ?? txn.userId,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    return await db.insert(
      'transactions',
      toInsert.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> softDeleteTransaction(String id) async {
    final db = await instance.database;
    await db.update(
      'transactions',
      {
        'deleted': 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Sync Engine Queries ---

  /// Finds rows updated since [lastSyncedAt] scoped to [userId] (including deleted for propagation).
  Future<List<TransactionModel>> getUnsyncedTransactions({
    required String userId,
    required String lastSyncedAt,
  }) async {
    final db = await instance.database;
    final result = await db.query(
      'transactions',
      where: 'user_id = ? AND updated_at > ?',
      whereArgs: [userId, lastSyncedAt],
    );
    return result.map((m) => TransactionModel.fromMap(m)).toList();
  }

  Future<int> getPendingSyncCount({
    required String? userId,
    required String lastSyncedAt,
  }) async {
    if (userId == null || userId.isEmpty) return 0;
    final db = await instance.database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM transactions WHERE user_id = ? AND updated_at > ?',
      [userId, lastSyncedAt],
    ));
    return count ?? 0;
  }

  Future<TransactionModel?> getTransactionById(String id) async {
    final db = await instance.database;
    final res = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return null;
    return TransactionModel.fromMap(res.first);
  }

  Future<void> upsertMergedTransaction(TransactionModel txn) async {
    final db = await instance.database;
    await db.insert(
      'transactions',
      txn.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> stampUserIdOnLocalRows(String userId) async {
    final db = await instance.database;
    await db.update(
      'transactions',
      {
        'user_id': userId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'user_id IS NULL OR user_id = ""',
    );
  }

  Future<void> deleteUserDataLocally({required String userId}) async {
    final db = await instance.database;
    await db.delete('transactions', where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<String> getLastSyncedAt({required String userId}) async {
    final db = await instance.database;
    final res = await db.query('sync_meta', where: 'key = ?', whereArgs: ['sync_$userId']);
    if (res.isEmpty) return '1970-01-01T00:00:00.000Z';
    return res.first['value'] as String;
  }

  Future<void> setLastSyncedAt({required String userId, required String timestamp}) async {
    final db = await instance.database;
    await db.insert(
      'sync_meta',
      {'key': 'sync_$userId', 'value': timestamp},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

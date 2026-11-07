import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ledgerlens/models/transaction_model.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Sync Engine & Last-Write-Wins Conflict Resolution Tests', () {
    late Database db;
    const testUserId = 'test_user_sibling_1';

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
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
          notes TEXT,
          user_id TEXT,
          updated_at TEXT,
          deleted INTEGER NOT NULL DEFAULT 0
        );
      ''');

      await db.execute('''
        CREATE TABLE sync_meta (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('LWW Conflict Resolution: Remote newer than local updates local SQLite', () async {
      // Local transaction created at 10:00
      final localTxn = TransactionModel(
        id: 'txn_sync_001',
        date: '2026-10-18',
        amount: 45000,
        direction: 'debit',
        rawDescription: 'SWIGGY',
        cleanMerchantName: 'Swiggy',
        categoryName: 'Food & Dining',
        confidence: 0.9,
        reviewStatus: 'needs_review',
        hash: 'hash_001',
        userId: testUserId,
        updatedAt: '2026-10-18T10:00:00.000Z',
      );
      await db.insert('transactions', localTxn.toMap());

      // Remote transaction updated at 11:30 with confirmed category and note
      final remoteTxn = TransactionModel(
        id: 'txn_sync_001',
        date: '2026-10-18',
        amount: 45000,
        direction: 'debit',
        rawDescription: 'SWIGGY',
        cleanMerchantName: 'Swiggy Biryani',
        categoryName: 'Food & Dining',
        confidence: 1.0,
        reviewStatus: 'confirmed',
        notes: 'Lunch with team',
        hash: 'hash_001',
        userId: testUserId,
        updatedAt: '2026-10-18T11:30:00.000Z',
      );

      // Simulate SyncService pull merge logic
      final localRow = (await db.query('transactions', where: 'id = ?', whereArgs: [remoteTxn.id])).firstOrNull;
      expect(localRow, isNotNull);

      final localUpdated = DateTime.parse(localRow!['updated_at'] as String);
      final remoteUpdated = DateTime.parse(remoteTxn.updatedAt);

      if (remoteUpdated.isAfter(localUpdated)) {
        await db.insert('transactions', remoteTxn.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      final merged = (await db.query('transactions', where: 'id = ?', whereArgs: ['txn_sync_001'])).first;
      expect(merged['clean_merchant_name'], 'Swiggy Biryani');
      expect(merged['review_status'], 'confirmed');
      expect(merged['notes'], 'Lunch with team');
      expect(merged['updated_at'], '2026-10-18T11:30:00.000Z');
    });

    test('LWW Conflict Resolution: Local newer than remote rejects stale remote row', () async {
      // Local transaction edited at 14:00
      final localTxn = TransactionModel(
        id: 'txn_sync_002',
        date: '2026-10-18',
        amount: 120000,
        direction: 'debit',
        rawDescription: 'AMAZON',
        cleanMerchantName: 'Amazon India (Local edit)',
        categoryName: 'Shopping',
        confidence: 1.0,
        reviewStatus: 'confirmed',
        hash: 'hash_002',
        userId: testUserId,
        updatedAt: '2026-10-18T14:00:00.000Z',
      );
      await db.insert('transactions', localTxn.toMap());

      // Stale remote row from 11:00
      final staleRemoteTxn = TransactionModel(
        id: 'txn_sync_002',
        date: '2026-10-18',
        amount: 120000,
        direction: 'debit',
        rawDescription: 'AMAZON',
        cleanMerchantName: 'Amazon Old',
        categoryName: 'Other',
        confidence: 0.5,
        reviewStatus: 'needs_review',
        hash: 'hash_002',
        userId: testUserId,
        updatedAt: '2026-10-18T11:00:00.000Z',
      );

      // Simulate SyncService pull merge logic
      final localRow = (await db.query('transactions', where: 'id = ?', whereArgs: [staleRemoteTxn.id])).first;
      final localUpdated = DateTime.parse(localRow['updated_at'] as String);
      final remoteUpdated = DateTime.parse(staleRemoteTxn.updatedAt);

      if (remoteUpdated.isAfter(localUpdated)) {
        await db.insert('transactions', staleRemoteTxn.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Local row must be preserved unchanged
      final preserved = (await db.query('transactions', where: 'id = ?', whereArgs: ['txn_sync_002'])).first;
      expect(preserved['clean_merchant_name'], 'Amazon India (Local edit)');
      expect(preserved['category_name'], 'Shopping');
      expect(preserved['updated_at'], '2026-10-18T14:00:00.000Z');
    });

    test('Offline Queueing: modified rows are queued until sync and scoped to user', () async {
      const lastSyncedAt = '2026-10-18T00:00:00.000Z';

      // 1. Transaction before lastSyncedAt (already synced)
      await db.insert('transactions', {
        'id': 'txn_synced_old',
        'date': '2026-10-17',
        'amount': 20000,
        'direction': 'debit',
        'raw_description': 'METRO',
        'clean_merchant_name': 'Metro',
        'category_name': 'Transportation',
        'confidence': 0.99,
        'review_status': 'confirmed',
        'hash': 'h1',
        'user_id': testUserId,
        'updated_at': '2026-10-17T18:00:00.000Z',
        'deleted': 0,
      });

      // 2. Offline transactions created after lastSyncedAt
      await db.insert('transactions', {
        'id': 'txn_offline_new1',
        'date': '2026-10-18',
        'amount': 30000,
        'direction': 'debit',
        'raw_description': 'COFFEE',
        'clean_merchant_name': 'Blue Tokai',
        'category_name': 'Food & Dining',
        'confidence': 0.99,
        'review_status': 'confirmed',
        'hash': 'h2',
        'user_id': testUserId,
        'updated_at': '2026-10-18T12:00:00.000Z',
        'deleted': 0,
      });

      await db.insert('transactions', {
        'id': 'txn_offline_new2',
        'date': '2026-10-18',
        'amount': 55000,
        'direction': 'debit',
        'raw_description': 'BOOKSTORE',
        'clean_merchant_name': 'Bookstore',
        'category_name': 'Shopping',
        'confidence': 0.99,
        'review_status': 'confirmed',
        'hash': 'h3',
        'user_id': testUserId,
        'updated_at': '2026-10-18T15:00:00.000Z',
        'deleted': 0,
      });

      // 3. Unsynced transaction from another user (must NOT appear in active user queue)
      await db.insert('transactions', {
        'id': 'txn_other_user',
        'date': '2026-10-18',
        'amount': 99000,
        'direction': 'debit',
        'raw_description': 'OTHER',
        'clean_merchant_name': 'Other',
        'category_name': 'Other',
        'confidence': 0.5,
        'review_status': 'confirmed',
        'hash': 'h4',
        'user_id': 'other_sibling_uuid',
        'updated_at': '2026-10-18T16:00:00.000Z',
        'deleted': 0,
      });

      // Query unsynced rows for testUserId
      final unsynced = await db.query(
        'transactions',
        where: 'user_id = ? AND updated_at > ?',
        whereArgs: [testUserId, lastSyncedAt],
      );

      expect(unsynced.length, 2);
      expect(unsynced.map((r) => r['id']).toSet(), {'txn_offline_new1', 'txn_offline_new2'});

      // Check pending count calculation
      final count = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM transactions WHERE user_id = ? AND updated_at > ?',
        [testUserId, lastSyncedAt],
      ));
      expect(count, 2);
    });

    test('Soft Delete Propagation: soft deleted row is queued for sync and hidden locally', () async {
      final txn = TransactionModel(
        id: 'txn_to_delete',
        date: '2026-10-18',
        amount: 75000,
        direction: 'debit',
        rawDescription: 'HOTEL',
        cleanMerchantName: 'Hotel Stay',
        categoryName: 'Travel',
        confidence: 0.99,
        reviewStatus: 'confirmed',
        hash: 'h_hotel',
        userId: testUserId,
        updatedAt: '2026-10-18T09:00:00.000Z',
      );
      await db.insert('transactions', txn.toMap());

      const lastSyncedAt = '2026-10-18T09:00:00.000Z';

      // Soft delete transaction
      final deleteTime = '2026-10-18T16:30:00.000Z';
      await db.update(
        'transactions',
        {
          'deleted': 1,
          'updated_at': deleteTime,
        },
        where: 'id = ?',
        whereArgs: ['txn_to_delete'],
      );

      // Verify normal active query hides it
      final activeRows = await db.query(
        'transactions',
        where: 'deleted = 0 AND (user_id = ? OR user_id IS NULL)',
        whereArgs: [testUserId],
      );
      expect(activeRows.isEmpty, isTrue);

      // Verify unsynced queue includes it so remote server receives the deletion flag
      final unsynced = await db.query(
        'transactions',
        where: 'user_id = ? AND updated_at > ?',
        whereArgs: [testUserId, lastSyncedAt],
      );
      expect(unsynced.length, 1);
      expect(unsynced.first['id'], 'txn_to_delete');
      expect(unsynced.first['deleted'], 1);
      expect(unsynced.first['updated_at'], deleteTime);
    });
  });
}

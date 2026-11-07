import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction_model.dart';
import 'database_service.dart';
import 'security_service.dart';

class SyncResult {
  final bool success;
  final int pushedCount;
  final int pulledCount;
  final String message;
  final bool isOffline;

  const SyncResult({
    required this.success,
    this.pushedCount = 0,
    this.pulledCount = 0,
    required this.message,
    this.isOffline = false,
  });

  factory SyncResult.offline(String reason) => SyncResult(
        success: false,
        message: reason,
        isOffline: true,
      );
}

class SyncService {
  static final SyncService instance = SyncService._init();
  bool _isInitialized = false;

  SyncService._init();

  bool get isConfigured => _isInitialized;

  SupabaseClient? get client {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Initializes Supabase using stored or provided credentials
  Future<bool> initialize({String? customUrl, String? customAnonKey}) async {
    final url = customUrl ?? await SecurityService.instance.getSupabaseUrl();
    final anonKey = customAnonKey ?? await SecurityService.instance.getSupabaseAnonKey();

    if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
      _isInitialized = false;
      return false;
    }

    try {
      if (Supabase.instance.isInitialized) {
        _isInitialized = true;
        return true;
      }

      // ignore: deprecated_member_use
      await Supabase.initialize(
        url: url.trim(),
        // ignore: deprecated_member_use
        anonKey: anonKey.trim(),
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _isInitialized = true;
      return true;
    } catch (e) {
      _isInitialized = false;
      return false;
    }
  }

  /// Sign in with Email and Password
  Future<AuthResponse?> signIn({
    required String email,
    required String password,
  }) async {
    final supabase = client;
    if (supabase == null) {
      throw Exception('Supabase is not configured. Please enter your project URL and Anon Key in Settings.');
    }

    final response = await supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    if (response.user != null) {
      await SecurityService.instance.setCachedUserId(response.user!.id);
      await SecurityService.instance.setCachedUserEmail(response.user!.email);
    }
    return response;
  }

  /// Sign out
  Future<void> signOut() async {
    final supabase = client;
    if (supabase != null) {
      try {
        await supabase.auth.signOut();
      } catch (_) {}
    }
    await SecurityService.instance.setCachedUserId(null);
    await SecurityService.instance.setCachedUserEmail(null);
  }

  String? get currentUserId {
    return client?.auth.currentUser?.id;
  }

  String? get currentUserEmail {
    return client?.auth.currentUser?.email;
  }

  /// Syncs local SQLite database with Supabase cloud using Last-Write-Wins
  Future<SyncResult> syncNow({required String userId}) async {
    final supabase = client;
    if (supabase == null || supabase.auth.currentUser == null) {
      return SyncResult.offline('Not signed in to Supabase. Cloud sync skipped.');
    }

    final activeUserId = supabase.auth.currentUser!.id;
    if (activeUserId != userId) {
      return SyncResult.offline('User session mismatch.');
    }

    try {
      final lastSyncedAt = await DatabaseService.instance.getLastSyncedAt(userId: activeUserId);
      final syncCycleStartTime = DateTime.now().toUtc().toIso8601String();

      // 1. PUSH PHASE: upload unsynced local rows
      final unsynced = await DatabaseService.instance.getUnsyncedTransactions(
        userId: activeUserId,
        lastSyncedAt: lastSyncedAt,
      );

      int pushed = 0;
      if (unsynced.isNotEmpty) {
        final payload = unsynced.map((t) => t.toSupabaseMap()).toList();
        await supabase.from('transactions').upsert(payload);
        pushed = unsynced.length;
      }

      // 2. PULL PHASE: fetch remote changes since lastSyncedAt
      final remoteRows = await supabase
          .from('transactions')
          .select()
          .eq('user_id', activeUserId)
          .gt('updated_at', lastSyncedAt);

      int pulled = 0;
      for (final raw in (remoteRows as List)) {
        final remoteTxn = TransactionModel.fromMap(raw as Map<String, dynamic>);
        final localTxn = await DatabaseService.instance.getTransactionById(remoteTxn.id);

        if (localTxn == null) {
          await DatabaseService.instance.upsertMergedTransaction(remoteTxn);
          pulled++;
        } else {
          // Last-Write-Wins Merge
          final localUpdated = DateTime.tryParse(localTxn.updatedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final remoteUpdated = DateTime.tryParse(remoteTxn.updatedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);

          if (remoteUpdated.isAfter(localUpdated)) {
            await DatabaseService.instance.upsertMergedTransaction(remoteTxn);
            pulled++;
          }
        }
      }

      // 3. UPDATE SYNC TIMESTAMP
      await DatabaseService.instance.setLastSyncedAt(
        userId: activeUserId,
        timestamp: syncCycleStartTime,
      );

      return SyncResult(
        success: true,
        pushedCount: pushed,
        pulledCount: pulled,
        message: 'Sync complete ($pushed pushed, $pulled pulled).',
      );
    } catch (e) {
      return SyncResult.offline('Network or server error during sync: ${e.toString()}');
    }
  }

  /// Deletes all cloud transactions belonging to the current user
  Future<bool> deleteMyCloudData({required String userId}) async {
    final supabase = client;
    if (supabase == null || supabase.auth.currentUser == null) return false;

    try {
      await supabase.from('transactions').delete().eq('user_id', userId);
      await DatabaseService.instance.setLastSyncedAt(
        userId: userId,
        timestamp: '1970-01-01T00:00:00.000Z',
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

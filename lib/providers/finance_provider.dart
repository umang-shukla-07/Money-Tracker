import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/gemini_service.dart';
import '../services/query_engine.dart';
import '../services/security_service.dart';
import '../services/statement_parser.dart';
import '../services/sync_service.dart';

class FinanceProvider extends ChangeNotifier {
  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _reviewQueue = [];
  bool _isLoading = true;
  bool _hasGeminiApiKey = false;

  // Multi-user & Sync state
  String? _currentUserId;
  String? _currentUserEmail;
  bool _isSyncing = false;
  String _lastSyncedAt = 'Never';
  int _pendingSyncCount = 0;

  // Filter state
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedAmountRange = 'all';

  List<TransactionModel> get allTransactions => _allTransactions;
  bool get hasGeminiApiKey => _hasGeminiApiKey;

  // Sync getters
  String? get currentUserId => _currentUserId;
  String? get currentUserEmail => _currentUserEmail;
  bool get isSignedIn => _currentUserId != null && _currentUserId!.isNotEmpty;
  bool get isSyncing => _isSyncing;
  String get lastSyncedAt => _lastSyncedAt;
  int get pendingSyncCount => _pendingSyncCount;

  List<TransactionModel> get transactions {
    return _allTransactions.where((t) {
      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = t.cleanMerchantName.toLowerCase().contains(q) ||
            t.rawDescription.toLowerCase().contains(q) ||
            t.categoryName.toLowerCase().contains(q);
        if (!match) return false;
      }
      // 2. Category Filter
      if (_selectedCategory != 'all' && t.categoryName != _selectedCategory) {
        return false;
      }
      // 3. Amount Range
      if (_selectedAmountRange == 'under_500' && t.amount > 50000) return false;
      if (_selectedAmountRange == '500_to_5000' && (t.amount <= 50000 || t.amount > 500000)) return false;
      if (_selectedAmountRange == 'over_5000' && t.amount <= 500000) return false;
      if (_selectedAmountRange == 'income' && !t.isCredit) return false;

      return true;
    }).toList();
  }

  List<TransactionModel> get reviewQueue => _reviewQueue;
  int get pendingReviewCount => _reviewQueue.length;
  bool get isLoading => _isLoading;

  // Financial Computations
  double get totalIncome {
    final credits = _allTransactions.where((t) => t.isCredit);
    final sum = credits.fold<int>(0, (prev, t) => prev + t.amount);
    return sum / 100.0;
  }

  double get totalExpense {
    final debits = _allTransactions.where((t) => t.isDebit);
    final sum = debits.fold<int>(0, (prev, t) => prev + t.amount);
    return sum / 100.0;
  }

  double get netFlow => totalIncome - totalExpense;

  double get savingsRate {
    if (totalIncome == 0) return 0.0;
    return (netFlow / totalIncome) * 100.0;
  }

  Map<String, double> get categoryBreakdown {
    final map = <String, double>{};
    for (final t in _allTransactions.where((t) => t.isDebit)) {
      map[t.categoryName] = (map[t.categoryName] ?? 0) + (t.amount / 100.0);
    }
    return map;
  }

  FinanceProvider() {
    init();
  }

  Future<void> init() async {
    await initSync();
    await loadData();
    await checkSecurityConfig();
  }

  Future<void> initSync() async {
    final configured = await SyncService.instance.initialize();
    if (configured) {
      _currentUserId = SyncService.instance.currentUserId ?? await SecurityService.instance.getCachedUserId();
      _currentUserEmail = SyncService.instance.currentUserEmail ?? await SecurityService.instance.getCachedUserEmail();
    } else {
      _currentUserId = await SecurityService.instance.getCachedUserId();
      _currentUserEmail = await SecurityService.instance.getCachedUserEmail();
    }
    await _refreshSyncMeta();
  }

  Future<void> _refreshSyncMeta() async {
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      final syncTime = await DatabaseService.instance.getLastSyncedAt(userId: _currentUserId!);
      if (syncTime == '1970-01-01T00:00:00.000Z') {
        _lastSyncedAt = 'Never';
      } else {
        final dt = DateTime.tryParse(syncTime)?.toLocal();
        if (dt != null) {
          _lastSyncedAt =
              '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } else {
          _lastSyncedAt = syncTime;
        }
      }
      _pendingSyncCount = await DatabaseService.instance.getPendingSyncCount(
        userId: _currentUserId,
        lastSyncedAt: syncTime,
      );
    } else {
      _lastSyncedAt = 'Never';
      _pendingSyncCount = 0;
    }
    notifyListeners();
  }

  Future<bool> configureSupabase(String url, String anonKey) async {
    await SecurityService.instance.setSupabaseUrl(url);
    await SecurityService.instance.setSupabaseAnonKey(anonKey);
    final ok = await SyncService.instance.initialize(customUrl: url, customAnonKey: anonKey);
    await _refreshSyncMeta();
    notifyListeners();
    return ok;
  }

  Future<bool> signInWithSupabase(String email, String password) async {
    final res = await SyncService.instance.signIn(email: email, password: password);
    if (res?.user != null) {
      final uid = res!.user!.id;
      _currentUserId = uid;
      _currentUserEmail = res.user!.email;
      // Stamp user_id on unassigned local transactions
      await DatabaseService.instance.stampUserIdOnLocalRows(uid);
      await loadData();
      // Background auto-sync after sign in
      syncNow();
      return true;
    }
    return false;
  }

  Future<void> signOutSupabase() async {
    await SyncService.instance.signOut();
    _currentUserId = null;
    _currentUserEmail = null;
    _lastSyncedAt = 'Never';
    _pendingSyncCount = 0;
    await loadData();
  }

  Future<SyncResult> syncNow() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      return SyncResult.offline('Please sign in to sync with Supabase.');
    }
    _isSyncing = true;
    notifyListeners();

    try {
      final result = await SyncService.instance.syncNow(userId: _currentUserId!);
      // Reload local data to reflect any pulled changes
      _allTransactions = await DatabaseService.instance.getAllTransactions(userId: _currentUserId);
      _reviewQueue = await DatabaseService.instance.getReviewQueue(userId: _currentUserId);
      await _refreshSyncMeta();
      return result;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<bool> deleteCloudData() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return false;
    _isSyncing = true;
    notifyListeners();
    try {
      final ok = await SyncService.instance.deleteMyCloudData(userId: _currentUserId!);
      if (ok) {
        await _refreshSyncMeta();
      }
      return ok;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> checkSecurityConfig() async {
    _hasGeminiApiKey = await SecurityService.instance.hasGeminiApiKey();
    notifyListeners();
  }

  Future<void> setGeminiApiKey(String key) async {
    await SecurityService.instance.setGeminiApiKey(key);
    await checkSecurityConfig();
  }

  Future<void> deleteGeminiApiKey() async {
    await SecurityService.instance.deleteGeminiApiKey();
    await checkSecurityConfig();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    _allTransactions = await DatabaseService.instance.getAllTransactions(userId: _currentUserId);
    _reviewQueue = await DatabaseService.instance.getReviewQueue(userId: _currentUserId);
    await _refreshSyncMeta();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> confirmReview(String id, {String? categoryName}) async {
    await DatabaseService.instance.confirmReview(id, categoryName: categoryName);
    await loadData();
    if (isSignedIn) {
      // Auto-sync after edit
      syncNow();
    }
  }

  /// Parses CSV statement through StatementParserService and inserts deduplicated rows
  Future<Map<String, int>> importStatement(String csvContent, {BankFormat? format}) async {
    final parsed = StatementParserService.parseCsv(csvContent, forceFormat: format);
    int imported = 0;
    int duplicates = 0;

    for (final txn in parsed) {
      final res = await DatabaseService.instance.insertTransaction(txn, userId: _currentUserId);
      if (res > 0) {
        imported++;
      } else {
        duplicates++;
      }
    }

    await loadData();
    if (isSignedIn && imported > 0) {
      // Auto-sync after import
      syncNow();
    }
    return {
      'total': parsed.length,
      'imported': imported,
      'duplicates': duplicates,
    };
  }

  /// Queries Gemini AI when API key is set; falls back to local QueryEngine if no key or offline
  Future<String> askQuery(String query) async {
    if (_hasGeminiApiKey) {
      final contextBuffer = StringBuffer();
      contextBuffer.writeln('Total Income: ₹$totalIncome, Total Expenses: ₹$totalExpense, Net Savings: ₹$netFlow');
      contextBuffer.writeln('Recent Transactions:');
      for (final t in _allTransactions.take(25)) {
        contextBuffer.writeln('${t.date} | ${t.cleanMerchantName} | ${t.formattedAmount} | ${t.categoryName}');
      }

      final aiResponse = await GeminiService.instance.askFinancialQuestion(
        question: query,
        financialContext: contextBuffer.toString(),
      );

      if (aiResponse != null && aiResponse.trim().isNotEmpty) {
        return aiResponse.trim();
      }
    }

    // Rules-only fallback execution
    final localResult = QueryEngine.executeQuery(query, _allTransactions);
    return localResult.answer;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategoryFilter(String cat) {
    _selectedCategory = cat;
    notifyListeners();
  }

  void setAmountRange(String range) {
    _selectedAmountRange = range;
    notifyListeners();
  }
}

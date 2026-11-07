import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';
import 'review_screen.dart';
import 'insights_screen.dart';
import 'ask_screen.dart';
import 'upload_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isLocked = false;
  bool _wasInBackground = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkColdStartLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasInBackground = true;
      _lockIfEnabled();
    } else if (state == AppLifecycleState.resumed) {
      if (_wasInBackground) {
        _wasInBackground = false;
        _authenticateIfEnabled();
      }
    }
  }

  Future<void> _lockIfEnabled() async {
    final enabled = await SecurityService.instance.isBiometricsEnabled();
    if (enabled && mounted) {
      setState(() => _isLocked = true);
    }
  }

  Future<void> _checkColdStartLock() async {
    final enabled = await SecurityService.instance.isBiometricsEnabled();
    if (enabled) {
      setState(() => _isLocked = true);
      await _authenticate();
    }
  }

  Future<void> _authenticateIfEnabled() async {
    final enabled = await SecurityService.instance.isBiometricsEnabled();
    if (enabled) {
      setState(() => _isLocked = true);
      await _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;

    final success = await SecurityService.instance.authenticate();
    _isAuthenticating = false;

    if (mounted) {
      if (success) {
        setState(() => _isLocked = false);
      }
    }
  }

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // If Biometric Lock is active, display the Privacy Shield Barrier
    if (_isLocked) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primary, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 32,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'LedgerLens Locked',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Biometric authentication required to view your financial data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _authenticate,
                  icon: const Icon(Icons.fingerprint, size: 20),
                  label: const Text('Unlock with Biometrics', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final finance = context.watch<FinanceProvider>();
    final pendingReview = finance.pendingReviewCount;

    final pages = [
      DashboardScreen(onNavigate: _onTabSelected),
      const TransactionsScreen(),
      const ReviewScreen(),
      const InsightsScreen(),
      const AskScreen(),
      const UploadScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabSelected,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Dash',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long),
                label: 'Txns',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: pendingReview > 0,
                  backgroundColor: AppTheme.warning,
                  label: Text(
                    '$pendingReview',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                  child: const Icon(Icons.inbox_outlined),
                ),
                activeIcon: Badge(
                  isLabelVisible: pendingReview > 0,
                  backgroundColor: AppTheme.warning,
                  label: Text(
                    '$pendingReview',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                  child: const Icon(Icons.inbox),
                ),
                label: 'Review',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.insights_outlined),
                activeIcon: Icon(Icons.insights),
                label: 'Insights',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.auto_awesome_outlined),
                activeIcon: Icon(Icons.auto_awesome),
                label: 'Ask',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.upload_file_outlined),
                activeIcon: Icon(Icons.upload_file),
                label: 'Upload',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

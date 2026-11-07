import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricLock = false;
  bool _hasApiKey = false;
  bool _hasSupabaseConfig = false;

  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _supabaseUrlController = TextEditingController();
  final TextEditingController _supabaseAnonKeyController = TextEditingController();
  final TextEditingController _authEmailController = TextEditingController();
  final TextEditingController _authPasswordController = TextEditingController();

  bool _isSigningIn = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _supabaseUrlController.dispose();
    _supabaseAnonKeyController.dispose();
    _authEmailController.dispose();
    _authPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final bio = await SecurityService.instance.isBiometricsEnabled();
    final hasKey = await SecurityService.instance.hasGeminiApiKey();
    final hasSupabase = await SecurityService.instance.hasSupabaseCredentials();
    final savedUrl = await SecurityService.instance.getSupabaseUrl();
    final savedKey = await SecurityService.instance.getSupabaseAnonKey();

    if (savedUrl != null) _supabaseUrlController.text = savedUrl;
    if (savedKey != null) _supabaseAnonKeyController.text = savedKey;

    if (mounted) {
      setState(() {
        _biometricLock = bio;
        _hasApiKey = hasKey;
        _hasSupabaseConfig = hasSupabase;
      });
    }
  }

  Future<void> _toggleBiometrics(bool enable) async {
    if (enable) {
      final success = await SecurityService.instance.authenticate();
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric authentication failed or canceled.')),
          );
        }
        return;
      }
    }
    await SecurityService.instance.setBiometricsEnabled(enable);
    setState(() => _biometricLock = enable);
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Gemini API Key', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Stored securely in Android Keystore / Encrypted Storage. If left blank, LedgerLens uses 100% offline heuristic categorization.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _apiKeyController,
                obscureText: true,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'Enter AIzaSy...',
                  hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textFaint),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            if (_hasApiKey)
              TextButton(
                onPressed: () async {
                  final finance = context.read<FinanceProvider>();
                  await finance.deleteGeminiApiKey();
                  _apiKeyController.clear();
                  Navigator.pop(ctx);
                  await _loadSettings();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gemini API key removed. Using rules fallback.')),
                    );
                  }
                },
                child: const Text('Clear Key', style: TextStyle(color: AppTheme.expense)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final key = _apiKeyController.text.trim();
                if (key.isNotEmpty) {
                  final finance = context.read<FinanceProvider>();
                  await finance.setGeminiApiKey(key);
                  _apiKeyController.clear();
                  Navigator.pop(ctx);
                  await _loadSettings();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✓ Gemini API key securely saved!')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showSupabaseConfigDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Supabase Cloud Setup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your Supabase Project URL and Public Anon Key. Only the public anon key is stored in encrypted storage; service_role is never used.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
                ),
                const SizedBox(height: 14),
                const Text('PROJECT URL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textFaint)),
                const SizedBox(height: 4),
                TextField(
                  controller: _supabaseUrlController,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'https://xyzcompany.supabase.co',
                    hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textFaint),
                    filled: true,
                    fillColor: AppTheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('PUBLIC ANON KEY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textFaint)),
                const SizedBox(height: 4),
                TextField(
                  controller: _supabaseAnonKeyController,
                  obscureText: true,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'eyJhbGciOiJIUzI1NiIsIn...',
                    hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textFaint),
                    filled: true,
                    fillColor: AppTheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (_hasSupabaseConfig)
              TextButton(
                onPressed: () async {
                  await SecurityService.instance.clearSupabaseCredentials();
                  _supabaseUrlController.clear();
                  _supabaseAnonKeyController.clear();
                  Navigator.pop(ctx);
                  await _loadSettings();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Supabase credentials cleared.')),
                    );
                  }
                },
                child: const Text('Reset', style: TextStyle(color: AppTheme.expense)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final url = _supabaseUrlController.text.trim();
                final key = _supabaseAnonKeyController.text.trim();
                if (url.isNotEmpty && key.isNotEmpty) {
                  final finance = context.read<FinanceProvider>();
                  final ok = await finance.configureSupabase(url, key);
                  Navigator.pop(ctx);
                  await _loadSettings();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? '✓ Supabase configured successfully!' : 'Failed to connect to Supabase.'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSignIn() async {
    final email = _authEmailController.text.trim();
    final password = _authPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password.')),
      );
      return;
    }

    setState(() => _isSigningIn = true);
    try {
      final finance = context.read<FinanceProvider>();
      final success = await finance.signInWithSupabase(email, password);
      if (success && mounted) {
        _authPasswordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ Signed in as $email')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  void _showDeleteCloudDataDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Cloud Data?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.expense)),
          content: const Text(
            'This permanently deletes all your transaction records stored on Supabase cloud. Local on-device transactions will NOT be deleted.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.expense,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final finance = context.read<FinanceProvider>();
                Navigator.pop(ctx);
                final ok = await finance.deleteCloudData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? '✓ Cloud transactions deleted.' : 'Failed to delete cloud data. Check connection.'),
                    ),
                  );
                }
              },
              child: const Text('Delete Cloud Copy'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Supabase Cloud Sync Section
          const Text(
            'CLOUD SYNC (SUPABASE)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.cloud_sync_outlined,
                            color: _hasSupabaseConfig ? AppTheme.primary : AppTheme.textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text('Supabase Backend', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _showSupabaseConfigDialog,
                        icon: const Icon(Icons.settings, size: 14, color: AppTheme.primary),
                        label: Text(
                          _hasSupabaseConfig ? 'Configure' : 'Setup URL',
                          style: const TextStyle(fontSize: 11, color: AppTheme.primary),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  if (!finance.isSignedIn) ...[
                    const Text(
                      'Multi-User Authentication',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sign in to synchronize with your sibling dashboard account. Scoped strictly to your user ID.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textFaint),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _authEmailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: const TextStyle(fontSize: 11, color: AppTheme.textFaint),
                        prefixIcon: const Icon(Icons.email_outlined, size: 16, color: AppTheme.textFaint),
                        filled: true,
                        fillColor: AppTheme.background,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _authPasswordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(fontSize: 11, color: AppTheme.textFaint),
                        prefixIcon: const Icon(Icons.lock_outline, size: 16, color: AppTheme.textFaint),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            size: 16,
                            color: AppTheme.textFaint,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        filled: true,
                        fillColor: AppTheme.background,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isSigningIn ? null : _handleSignIn,
                        child: _isSigningIn
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Text('Sign In to Sync', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else ...[
                    // Signed In Account State
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.primary.withOpacity(0.2),
                          radius: 18,
                          child: const Icon(Icons.person, color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                finance.currentUserEmail ?? 'Authenticated User',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'User ID: ${finance.currentUserId?.substring(0, 8)}...',
                                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textFaint),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.border),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () async {
                            await finance.signOutSupabase();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Signed out of Supabase.')),
                              );
                            }
                          },
                          child: const Text('Sign Out', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    // Sync Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Last Synced', style: TextStyle(fontSize: 10, color: AppTheme.textFaint)),
                            const SizedBox(height: 2),
                            Text(finance.lastSyncedAt, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Pending Changes', style: TextStyle(fontSize: 10, color: AppTheme.textFaint)),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: finance.pendingSyncCount > 0 ? Colors.amber.withOpacity(0.15) : AppTheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                finance.pendingSyncCount > 0 ? '${finance.pendingSyncCount} pending' : '✓ In sync',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: finance.pendingSyncCount > 0 ? Colors.amber : AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: finance.isSyncing
                                ? null
                                : () async {
                                    final res = await finance.syncNow();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(res.message)),
                                      );
                                    }
                                  },
                            icon: finance.isSyncing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : const Icon(Icons.sync, size: 16),
                            label: Text(finance.isSyncing ? 'Syncing...' : 'Sync Now', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.expense,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          onPressed: finance.isSyncing ? null : _showDeleteCloudDataDialog,
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Delete Cloud Data', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Security Section
          const Text(
            'PRIVACY & SECURITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint, color: AppTheme.primary),
                  title: const Text('Biometric App Lock', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Require fingerprint on open and resume', style: TextStyle(fontSize: 11, color: AppTheme.textFaint)),
                  value: _biometricLock,
                  activeColor: AppTheme.primary,
                  onChanged: (val) => _toggleBiometrics(val),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.screenshot_outlined, color: AppTheme.primary),
                  title: const Text('Recent Apps Protection (FLAG_SECURE)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Screenshots blocked & app preview blanked in task switcher', style: TextStyle(fontSize: 11, color: AppTheme.textFaint)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // AI Configuration Section
          const Text(
            'AI ASSISTANT (OPTIONAL)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.key, color: Colors.purpleAccent),
              title: const Text('Google Gemini API Key', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(
                _hasApiKey ? 'Configured securely (Encrypted Storage)' : 'Not set — using offline heuristic rules',
                style: const TextStyle(fontSize: 11, color: AppTheme.textFaint),
              ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.surfaceSubtle,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: _showApiKeyDialog,
                child: Text(_hasApiKey ? 'Manage' : 'Add Key', style: const TextStyle(fontSize: 11)),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Database Section
          const Text(
            'STORAGE & SYSTEM',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storage, color: AppTheme.primary),
                  title: const Text('Local SQLite Database', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('${finance.transactions.length} transactions stored on-device', style: const TextStyle(fontSize: 11, color: AppTheme.textFaint)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Healthy', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.description_outlined, color: AppTheme.textMuted),
                  title: Text('Accounting Precision', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('Strict integer-paise (Zero floating point errors)', style: TextStyle(fontSize: 11, color: AppTheme.textFaint)),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.info_outline, color: AppTheme.textMuted),
                  title: Text('App Version', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  trailing: Text('1.0.0', style: TextStyle(fontSize: 12, color: AppTheme.textFaint)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

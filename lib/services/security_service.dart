import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  static final SecurityService instance = SecurityService._init();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _keyGeminiApi = 'gemini_api_key';
  static const String _keyBiometrics = 'biometric_lock_enabled';

  // Supabase secure keys
  static const String _keySupabaseUrl = 'supabase_url';
  static const String _keySupabaseAnonKey = 'supabase_anon_key';
  static const String _keySupabaseUserId = 'supabase_user_id';
  static const String _keySupabaseUserEmail = 'supabase_user_email';

  SecurityService._init();

  // Gemini API Key Management
  Future<String?> getGeminiApiKey() async {
    try {
      return await _storage.read(key: _keyGeminiApi);
    } catch (_) {
      return null;
    }
  }

  Future<void> setGeminiApiKey(String key) async {
    await _storage.write(key: _keyGeminiApi, value: key.trim());
  }

  Future<void> deleteGeminiApiKey() async {
    await _storage.delete(key: _keyGeminiApi);
  }

  Future<bool> hasGeminiApiKey() async {
    final key = await getGeminiApiKey();
    return key != null && key.isNotEmpty;
  }

  // Supabase Credentials Management
  Future<String?> getSupabaseUrl() async {
    try {
      return await _storage.read(key: _keySupabaseUrl);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getSupabaseAnonKey() async {
    try {
      return await _storage.read(key: _keySupabaseAnonKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> setSupabaseUrl(String url) async {
    await _storage.write(key: _keySupabaseUrl, value: url.trim());
  }

  Future<void> setSupabaseAnonKey(String anonKey) async {
    await _storage.write(key: _keySupabaseAnonKey, value: anonKey.trim());
  }

  Future<void> setSupabaseCredentials({
    required String url,
    required String anonKey,
  }) async {
    await _storage.write(key: _keySupabaseUrl, value: url.trim());
    await _storage.write(key: _keySupabaseAnonKey, value: anonKey.trim());
  }

  Future<void> clearSupabaseCredentials() async {
    await _storage.delete(key: _keySupabaseUrl);
    await _storage.delete(key: _keySupabaseAnonKey);
    await _storage.delete(key: _keySupabaseUserId);
    await _storage.delete(key: _keySupabaseUserEmail);
  }

  Future<bool> hasSupabaseCredentials() async {
    final url = await getSupabaseUrl();
    final anonKey = await getSupabaseAnonKey();
    return url != null && url.isNotEmpty && anonKey != null && anonKey.isNotEmpty;
  }

  // Session caching
  Future<String?> getCachedUserId() async {
    try {
      return await _storage.read(key: _keySupabaseUserId);
    } catch (_) {
      return null;
    }
  }

  Future<void> setCachedUserId(String? userId) async {
    if (userId == null) {
      await _storage.delete(key: _keySupabaseUserId);
    } else {
      await _storage.write(key: _keySupabaseUserId, value: userId);
    }
  }

  Future<String?> getCachedUserEmail() async {
    try {
      return await _storage.read(key: _keySupabaseUserEmail);
    } catch (_) {
      return null;
    }
  }

  Future<void> setCachedUserEmail(String? email) async {
    if (email == null) {
      await _storage.delete(key: _keySupabaseUserEmail);
    } else {
      await _storage.write(key: _keySupabaseUserEmail, value: email);
    }
  }

  // Biometrics Management
  Future<bool> isBiometricsEnabled() async {
    try {
      final val = await _storage.read(key: _keyBiometrics);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometrics, value: enabled ? 'true' : 'false');
  }

  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock LedgerLens to view private financial data',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

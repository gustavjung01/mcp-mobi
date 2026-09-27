import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../installation/installation_profile.dart';

abstract interface class SessionStore {
  Future<InstallationProfile?> readProfile();

  Future<String?> readToken(InstallationProfile profile);

  Future<void> saveProfile(InstallationProfile profile);

  Future<void> saveSession(InstallationProfile profile, String token);

  Future<void> clearSession({bool keepProfile = true});

  Future<void> clearAll();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const _profileKey = 'mcp.installation.profile';
  static const _tokenKey = 'mcp.session.token';
  static const _tokenInstallationKey = 'mcp.session.installation';

  final FlutterSecureStorage _storage;

  @override
  Future<InstallationProfile?> readProfile() async {
    final raw = await _storage.read(key: _profileKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return InstallationProfile.fromJson(decoded);
    } on FormatException {
      await clearAll();
      return null;
    }
  }

  @override
  Future<String?> readToken(InstallationProfile profile) async {
    final installationKey = await _storage.read(key: _tokenInstallationKey);
    if (installationKey != profile.installationKey) return null;
    final token = (await _storage.read(key: _tokenKey))?.trim() ?? '';
    return token.startsWith('nppusr.') ? token : null;
  }

  @override
  Future<void> saveProfile(InstallationProfile profile) async {
    final current = await readProfile();
    if (current?.installationKey != profile.installationKey) {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _tokenInstallationKey);
    }
    await _storage.write(
      key: _profileKey,
      value: jsonEncode(profile.toJson()),
    );
  }

  @override
  Future<void> saveSession(
    InstallationProfile profile,
    String token,
  ) async {
    if (!token.startsWith('nppusr.')) {
      throw ArgumentError.value(token, 'token', 'Invalid session token');
    }
    await saveProfile(profile);
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(
      key: _tokenInstallationKey,
      value: profile.installationKey,
    );
  }

  @override
  Future<void> clearSession({bool keepProfile = true}) async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _tokenInstallationKey);
    if (!keepProfile) await _storage.delete(key: _profileKey);
  }

  @override
  Future<void> clearAll() => clearSession(keepProfile: false);
}

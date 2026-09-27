import 'package:flutter/material.dart';

import '../../core/auth/mobile_auth_client.dart';
import '../../core/installation/installation_profile.dart';
import '../../core/session/session_store.dart';
import '../../features/auth/login_page.dart';
import '../../features/bootstrap/system_setup_page.dart';
import '../../features/settings/settings_page.dart';
import '../navigation/app_shell.dart';
import '../theme/app_theme.dart';

enum _BootstrapState {
  loading,
  setup,
  login,
  ready,
  unavailable,
}

class BootstrapFlow extends StatefulWidget {
  const BootstrapFlow({
    required this.authClient,
    required this.sessionStore,
    super.key,
  });

  final MobileAuthClient authClient;
  final SessionStore sessionStore;

  @override
  State<BootstrapFlow> createState() => _BootstrapFlowState();
}

class _BootstrapFlowState extends State<BootstrapFlow> {
  _BootstrapState _state = _BootstrapState.loading;
  InstallationProfile? _profile;
  MobileSession? _session;
  String _unavailableMessage = '';

  @override
  void initState() {
    super.initState();
    _restore();
  }

  bool _isExpiredSession(AuthFailure failure) {
    return failure.code == 'UNAUTHORIZED' ||
        failure.code == 'FORBIDDEN' ||
        failure.code == 'INTERNAL_AUTH_SESSION_INVALID' ||
        failure.code == 'INTERNAL_AUTH_SESSION_REVOKED' ||
        failure.code == 'INTERNAL_AUTH_SESSION_EXPIRED';
  }

  Future<void> _restore() async {
    if (mounted) {
      setState(() {
        _state = _BootstrapState.loading;
      });
    }

    try {
      var profile = await widget.sessionStore.readProfile();
      if (!mounted) return;

      final productionProfile = InstallationProfile.productionDefault();
      if (productionProfile != null &&
          (profile == null ||
              profile.baseUrl != productionProfile.baseUrl ||
              profile.fieldBaseUrl != productionProfile.fieldBaseUrl)) {
        await widget.sessionStore.saveProfile(productionProfile);
        profile = productionProfile;
      }

      if (profile == null) {
        setState(() {
          _profile = null;
          _session = null;
          _state = _BootstrapState.setup;
        });
        return;
      }

      final token = await widget.sessionStore.readToken(profile);
      if (!mounted) return;
      if (token == null) {
        setState(() {
          _profile = profile;
          _session = null;
          _state = _BootstrapState.login;
        });
        return;
      }

      try {
        final session = await widget.authClient.me(
          profile: profile,
          token: token,
        );
        if (!mounted) return;
        setState(() {
          _profile = profile;
          _session = session;
          _state = _BootstrapState.ready;
        });
      } on AuthFailure catch (failure) {
        if (_isExpiredSession(failure)) {
          await widget.sessionStore.clearSession();
          if (!mounted) return;
          setState(() {
            _profile = profile;
            _session = null;
            _state = _BootstrapState.login;
          });
          return;
        }

        if (!mounted) return;
        setState(() {
          _profile = profile;
          _session = null;
          _unavailableMessage = failure.message;
          _state = _BootstrapState.unavailable;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profile = null;
        _session = null;
        _unavailableMessage =
            'Không đọc được thiết lập ứng dụng. Vui lòng thử lại.';
        _state = _BootstrapState.unavailable;
      });
    }
  }

  Future<void> _selectProfile(InstallationProfile profile) async {
    await widget.sessionStore.saveProfile(profile);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _session = null;
      _state = _BootstrapState.login;
    });
  }

  Future<void> _authenticated(MobileSession session) async {
    final profile = _profile;
    if (profile == null) return;
    await widget.sessionStore.saveSession(profile, session.token);
    if (!mounted) return;
    setState(() {
      _session = session;
      _state = _BootstrapState.ready;
    });
  }

  Future<void> _changeSystem() async {
    final profile = _profile;
    final session = _session;
    await widget.sessionStore.clearAll();

    if (profile != null && session != null) {
      try {
        await widget.authClient.logout(
          profile: profile,
          token: session.token,
        );
      } on AuthFailure {
        // Local isolation is authoritative when the system is changed.
      }
    }

    if (!mounted) return;
    final productionProfile = InstallationProfile.productionDefault();
    if (productionProfile != null) {
      await widget.sessionStore.saveProfile(productionProfile);
      if (!mounted) return;
      setState(() {
        _profile = productionProfile;
        _session = null;
        _state = _BootstrapState.login;
      });
      return;
    }

    setState(() {
      _profile = null;
      _session = null;
      _state = _BootstrapState.setup;
    });
  }

  Future<void> _logout() async {
    final profile = _profile;
    final session = _session;
    if (profile == null || session == null) return;

    await widget.sessionStore.clearSession();
    try {
      await widget.authClient.logout(
        profile: profile,
        token: session.token,
      );
    } on AuthFailure {
      // The local token is already removed so the app remains signed out.
    }

    if (!mounted) return;
    setState(() {
      _session = null;
      _state = _BootstrapState.login;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _BootstrapState.loading:
        return const _LoadingScreen();
      case _BootstrapState.setup:
        return SystemSetupPage(onContinue: _selectProfile);
      case _BootstrapState.login:
        final profile = _profile;
        if (profile == null) return const _LoadingScreen();
        return LoginPage(
          profile: profile,
          authClient: widget.authClient,
          onAuthenticated: _authenticated,
          onChangeSystem: _changeSystem,
        );
      case _BootstrapState.ready:
        final profile = _profile;
        final session = _session;
        if (profile == null || session == null) return const _LoadingScreen();
        return AppShell(
          profile: profile,
          session: session,
          onLogout: _logout,
        );
      case _BootstrapState.unavailable:
        return _UnavailableScreen(
          message: _unavailableMessage,
          onRetry: _restore,
          onChangeSystem: _changeSystem,
        );
    }
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('bootstrap-loading-screen'),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.storefront_rounded,
                size: 52,
                color: AppColors.primary,
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                'MCP Field',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnavailableScreen extends StatelessWidget {
  const _UnavailableScreen({
    required this.message,
    required this.onRetry,
    required this.onChangeSystem,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onChangeSystem;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('bootstrap-unavailable-screen'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 54,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Chưa kết nối được hệ thống',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const Key('bootstrap-update-app'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.system_update_alt_rounded),
                label: const Text('Cập nhật ứng dụng'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: onChangeSystem,
                child: const Text('Đổi hệ thống'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

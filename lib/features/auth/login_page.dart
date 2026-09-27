import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/auth/mobile_auth_client.dart';
import '../../core/installation/installation_profile.dart';
import '../../shared/widgets/app_card.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.profile,
    required this.authClient,
    required this.onAuthenticated,
    required this.onChangeSystem,
    super.key,
  });

  final InstallationProfile profile;
  final MobileAuthClient authClient;
  final Future<void> Function(MobileSession session) onAuthenticated;
  final Future<void> Function() onChangeSystem;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ownerCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _ownerCodeRequired = false;
  bool _busy = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    _ownerCodeController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final loginName = _userController.text.trim();
    final password = _passwordController.text;
    final ownerCode = _ownerCodeController.text.trim();

    if (loginName.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Nhập tên đăng nhập và mật khẩu.';
      });
      return;
    }
    if (_ownerCodeRequired && ownerCode.isEmpty) {
      setState(() {
        _errorMessage = 'Nhập mã xác nhận để tiếp tục.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = '';
    });

    try {
      final session = await widget.authClient.login(
        profile: widget.profile,
        loginName: loginName,
        password: password,
        ownerCode: ownerCode,
      );
      await widget.onAuthenticated(session);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      final challenge =
          failure.code == 'INTERNAL_AUTH_OWNER_CHALLENGE_REQUIRED' ||
          failure.code == 'INTERNAL_AUTH_OWNER_CODE_INVALID';
      setState(() {
        _busy = false;
        _ownerCodeRequired = challenge || _ownerCodeRequired;
        _errorMessage = failure.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = 'Không thể đăng nhập. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      key: const Key('login-screen'),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryDeep,
                  AppColors.primaryDark,
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton.filledTonal(
                      onPressed: _busy
                          ? null
                          : () {
                              widget.onChangeSystem();
                            },
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0x26FFFFFF),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: const Color(0x88FFFFFF),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      'Đăng nhập',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.profile.name,
                      style: const TextStyle(
                        color: Color(0xFFD9E9FF),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(
                                AppRadius.md,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.profile.name,
                                  style: textTheme.titleMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.profile.baseUrl.host,
                                  style: textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    widget.onChangeSystem();
                                  },
                            child: const Text('Đổi'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      TextField(
                        key: const Key('login-user-field'),
                        controller: _userController,
                        enabled: !_busy && !_ownerCodeRequired,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Tên đăng nhập',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        key: const Key('login-password-field'),
                        controller: _passwordController,
                        enabled: !_busy && !_ownerCodeRequired,
                        obscureText: _obscurePassword,
                        textInputAction: _ownerCodeRequired
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onSubmitted: (_) {
                          if (!_ownerCodeRequired) _login();
                        },
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                          ),
                          suffixIcon: IconButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      if (_ownerCodeRequired) ...[
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          key: const Key('login-owner-code-field'),
                          controller: _ownerCodeController,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _login(),
                          decoration: const InputDecoration(
                            labelText: 'Mã xác nhận',
                            hintText: 'Nhập mã đã được gửi',
                            prefixIcon: Icon(Icons.verified_user_outlined),
                          ),
                        ),
                      ],
                      if (_errorMessage.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.dangerSoft,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            _errorMessage,
                            key: const Key('login-error-message'),
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton.icon(
                        key: const Key('login-button'),
                        onPressed: _busy ? null : _login,
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _ownerCodeRequired
                                    ? Icons.verified_outlined
                                    : Icons.login_rounded,
                              ),
                        label: Text(
                          _ownerCodeRequired ? 'Xác nhận' : 'Đăng nhập',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

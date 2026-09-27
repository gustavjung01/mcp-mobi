import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/installation/installation_profile.dart';
import '../../core/installation/system_endpoint_probe.dart';
import '../../shared/widgets/app_card.dart';
import '../settings/settings_page.dart';

class SystemSetupPage extends StatefulWidget {
  const SystemSetupPage({
    required this.onContinue,
    required this.endpointProbe,
    super.key,
  });

  final ValueChanged<InstallationProfile> onContinue;
  final SystemEndpointProbe endpointProbe;

  @override
  State<SystemSetupPage> createState() => _SystemSetupPageState();
}

class _SystemSetupPageState extends State<SystemSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late final TextEditingController _urlController;
  late final bool _usesConfiguredApiBaseUrl;
  bool _checking = false;
  String _endpointError = '';

  @override
  void initState() {
    super.initState();
    final configured = InstallationProfile.configuredApiBaseUrl();
    _usesConfiguredApiBaseUrl = configured != null;
    _urlController = TextEditingController(
      text: configured?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_checking || !_formKey.currentState!.validate()) return;

    final uri = InstallationProfile.parseBaseUrl(_urlController.text);
    if (uri == null) return;

    setState(() {
      _checking = true;
      _endpointError = '';
    });

    try {
      await widget.endpointProbe.verify(uri);
      if (!mounted) return;
      widget.onContinue(
        InstallationProfile.selected(
          name: _nameController.text.trim(),
          baseUrl: uri,
        ),
      );
    } on SystemEndpointFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _endpointError = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      key: const Key('system-setup-screen'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF36A1FF),
                        AppColors.primary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x261677FF),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 34,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MCP Field',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Ứng dụng dành cho Nhân viên thị trường',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Text(
              'Chọn hệ thống',
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Mỗi bộ cài đặt sử dụng hệ thống riêng. Ứng dụng sẽ kiểm tra máy chủ trước khi đăng nhập.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thông tin hệ thống',
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      key: const Key('system-name-field'),
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Tên hệ thống',
                        hintText: 'Ví dụ: Hưng Phát',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Nhập tên hệ thống';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const Key('system-url-field'),
                      controller: _urlController,
                      readOnly: _usesConfiguredApiBaseUrl,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _continue(),
                      decoration: InputDecoration(
                        labelText: 'Địa chỉ máy chủ',
                        hintText: 'https://dia-chi-may-chu',
                        prefixIcon: const Icon(Icons.dns_outlined),
                        suffixIcon: _usesConfiguredApiBaseUrl
                            ? const Icon(Icons.lock_outline_rounded)
                            : null,
                      ),
                      validator: (value) {
                        final uri = InstallationProfile.parseBaseUrl(
                          value ?? '',
                        );
                        if (uri == null) {
                          return 'Địa chỉ máy chủ chưa hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Chỉ dùng địa chỉ máy chủ MCP Field do Công Ty cấp. Không nhập địa chỉ trang web quản lý.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_endpointError.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _endpointError,
                        key: const Key('system-endpoint-error'),
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton.icon(
                      key: const Key('system-continue-button'),
                      onPressed: _checking ? null : _continue,
                      icon: _checking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_forward_rounded),
                      label: Text(
                        _checking ? 'Đang kiểm tra' : 'Tiếp tục',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              key: const Key('system-update-app'),
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
          ],
        ),
      ),
    );
  }
}

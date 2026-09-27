import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/installation/installation_profile.dart';
import '../../shared/widgets/app_card.dart';

class SystemSetupPage extends StatefulWidget {
  const SystemSetupPage({
    required this.onContinue,
    super.key,
  });

  final ValueChanged<InstallationProfile> onContinue;

  @override
  State<SystemSetupPage> createState() => _SystemSetupPageState();
}

class _SystemSetupPageState extends State<SystemSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;

    final uri = InstallationProfile.parseBaseUrl(_urlController.text);
    if (uri == null) return;

    widget.onContinue(
      InstallationProfile(
        name: _nameController.text.trim(),
        baseUrl: uri,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Mỗi bộ cài đặt sử dụng hệ thống riêng. Thiết lập đúng hệ thống trước khi đăng nhập.',
              style: Theme.of(context).textTheme.bodyMedium,
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
                      style: Theme.of(context).textTheme.titleMedium,
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
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _continue(),
                      decoration: const InputDecoration(
                        labelText: 'Địa chỉ hệ thống',
                        hintText: 'https://mcp.tencongty.vn',
                        prefixIcon: Icon(Icons.language_rounded),
                      ),
                      validator: (value) {
                        if (InstallationProfile.parseBaseUrl(value ?? '') == null) {
                          return 'Địa chỉ hệ thống chưa hợp lệ';
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
                            'Ứng dụng chỉ kết nối tới hệ thống đã chọn, không kết nối trực tiếp cơ sở dữ liệu.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton.icon(
                      key: const Key('system-continue-button'),
                      onPressed: _continue,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Tiếp tục'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

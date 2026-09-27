import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/update/app_update_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/navy_page_header.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.updateService,
  });

  final AppUpdateService? updateService;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final AppUpdateService _updates;
  String _currentVersion = '...';
  AppUpdateCheck? _check;
  String? _message;
  bool _checking = false;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    _updates = widget.updateService ?? AppUpdateService();
    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final version = await _updates.currentVersion();
      if (!mounted) return;
      setState(() {
        _currentVersion = version.isEmpty ? 'Không xác định' : version;
      });
    } on AppUpdateFailure {
      if (!mounted) return;
      setState(() {
        _currentVersion = 'Không xác định';
      });
    }
  }

  Future<void> _checkUpdate() async {
    if (_checking || _installing) return;
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      final check = await _updates.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _check = check;
        _currentVersion = check.currentVersion;
        _message = check.updateAvailable
            ? 'Có bản ${check.release.version} mới.'
            : 'Ứng dụng đang ở bản mới nhất.';
      });
    } on AppUpdateFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _check = null;
        _message = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  Future<void> _installUpdate() async {
    final release = _check?.release;
    if (release == null || _installing) return;

    setState(() {
      _installing = true;
      _message = null;
    });
    try {
      final allowed = await _updates.canInstallPackages();
      if (!allowed) {
        await _updates.openInstallPermissionSettings();
        if (!mounted) return;
        setState(() {
          _message = 'Bật “Cho phép từ nguồn này”, quay lại MCP Field rồi bấm Cài bản cập nhật.';
        });
        return;
      }

      await _updates.install(release);
      if (!mounted) return;
      setState(() {
        _message = 'Đã tải và kiểm tra file. Android đang mở màn hình cài đặt.';
      });
    } on AppUpdateFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _message = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _installing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final release = _check?.release;
    final updateAvailable = _check?.updateAvailable == true;

    return Scaffold(
      key: const Key('settings-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: 'Thiết lập',
            subtitle: 'Cài đặt ứng dụng và cập nhật phiên bản',
            leading: IconButton(
              key: const Key('settings-back'),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.system_update_alt_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cập nhật ứng dụng',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Tải bản mới chính thức của MCP Field',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SettingRow(
                        label: 'Bản đang dùng',
                        value: _currentVersion,
                      ),
                      if (release != null) ...[
                        const Divider(height: 24),
                        _SettingRow(
                          label: 'Bản phát hành',
                          value: release.version,
                        ),
                        if (release.size > 0) ...[
                          const Divider(height: 24),
                          _SettingRow(
                            label: 'Dung lượng',
                            value: _formatBytes(release.size),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Text(
                            release.releaseNotes,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                      if ((_message ?? '').isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _message!,
                          key: const Key('update-message'),
                          style: TextStyle(
                            color: updateAvailable
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: updateAvailable
                            ? FilledButton.icon(
                                key: const Key('install-update-button'),
                                onPressed: _installing || _checking
                                    ? null
                                    : _installUpdate,
                                icon: _installing
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.download_for_offline_outlined,
                                      ),
                                label: Text(
                                  _installing
                                      ? 'Đang tải bản cập nhật...'
                                      : 'Tải và cài bản ${release!.version}',
                                ),
                              )
                            : OutlinedButton.icon(
                                key: const Key('check-update-button'),
                                onPressed: _checking || _installing
                                    ? null
                                    : _checkUpdate,
                                icon: _checking
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh_rounded),
                                label: Text(
                                  _checking
                                      ? 'Đang kiểm tra...'
                                      : 'Kiểm tra cập nhật',
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  key: const Key('update-install-guide'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.help_outline_rounded,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Nếu Android chặn cài đặt',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const _InstallGuideStep(
                        number: '1',
                        text: 'Nếu Google Play Protect hiện cảnh báo, chọn “Tiếp tục cài đặt”.',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const _InstallGuideStep(
                        number: '2',
                        text: 'Nếu máy yêu cầu quyền cài ứng dụng không xác định, bật “Cho phép từ nguồn này” cho MCP Field.',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const _InstallGuideStep(
                        number: '3',
                        text: 'Quay lại MCP Field và bấm cài bản cập nhật một lần nữa.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'MCP Field kiểm tra file cập nhật trước khi mở trình cài đặt Android.',
                          style: Theme.of(context).textTheme.bodyMedium,
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

class _InstallGuideStep extends StatelessWidget {
  const _InstallGuideStep({
    required this.number,
    required this.text,
  });

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}

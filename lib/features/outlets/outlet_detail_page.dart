import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_data_client.dart';
import '../../shared/widgets/app_card.dart';

class OutletDetailPage extends StatelessWidget {
  const OutletDetailPage({
    required this.routeName,
    super.key,
    this.customer,
    this.line,
  });

  final String routeName;
  final FieldRouteCustomer? customer;
  final FieldDayLine? line;

  @override
  Widget build(BuildContext context) {
    final name = line?.accountName ?? customer?.accountName ?? 'Điểm bán';
    final area = line?.area ?? customer?.area ?? 'Chưa có khu vực';
    final phone = (line?.phone ?? '').trim();
    final address = (line?.address ?? '').trim();
    final contact = (customer?.contactName ?? '').trim();
    final note = _firstNonEmpty([line?.note, customer?.note]);
    final accountId = (customer?.accountId ?? '').trim();
    final checkedIn = line?.checkedIn == true;
    final visited = line?.status == 'visited';
    final gps = customer?.gps;

    return Scaffold(
      key: const Key('outlet-detail-screen'),
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
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      color: Colors.white,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      routeName,
                      style: const TextStyle(
                        color: Color(0xFFD8E8FF),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    StatusPill(
                      label: checkedIn
                          ? 'Đã check-in'
                          : visited
                          ? 'Đã ghé'
                          : 'Chưa ghé',
                      icon: checkedIn
                          ? Icons.location_on_rounded
                          : visited
                          ? Icons.check_circle_outline_rounded
                          : Icons.schedule_rounded,
                      backgroundColor: checkedIn || visited
                          ? AppColors.successSoft
                          : const Color(0x26FFFFFF),
                      foregroundColor: checkedIn || visited
                          ? AppColors.success
                          : Colors.white,
                    ),
                  ],
                ),
              ),
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
                      const Text(
                        'Thông tin điểm bán',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _InfoRow(
                        label: 'Mã điểm bán',
                        value: accountId.isEmpty ? 'Chưa có' : accountId,
                      ),
                      const Divider(height: 22),
                      _InfoRow(label: 'Khu vực', value: area),
                      const Divider(height: 22),
                      _InfoRow(
                        label: 'Địa chỉ',
                        value: address.isEmpty ? 'Chưa có địa chỉ' : address,
                      ),
                      const Divider(height: 22),
                      _InfoRow(
                        label: 'Điện thoại',
                        value: phone.isEmpty ? 'Chưa có' : phone,
                      ),
                      const Divider(height: 22),
                      _InfoRow(
                        label: 'Người liên hệ',
                        value: contact.isEmpty ? 'Chưa có' : contact,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trạng thái hôm nay',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _InfoRow(
                        label: 'Ghé điểm bán',
                        value: visited ? 'Đã ghé' : 'Chưa ghé',
                      ),
                      const Divider(height: 22),
                      _InfoRow(
                        label: 'Check-in',
                        value: checkedIn
                            ? _formatDateTime(line?.checkinAt)
                            : 'Chưa check-in',
                      ),
                      const Divider(height: 22),
                      _InfoRow(
                        label: 'Vị trí điểm bán',
                        value: gps == null ? 'Chưa có GPS' : _gpsText(gps),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Hoạt động trong phiên',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _ActivityCard(
                        icon: Icons.receipt_long_outlined,
                        label: 'Đơn hàng',
                        active: line?.hasOrder == true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ActivityCard(
                        icon: Icons.assignment_outlined,
                        label: 'Báo cáo',
                        active: line?.hasReport == true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _ActivityCard(
                        icon: Icons.science_outlined,
                        label: 'Thử sản phẩm',
                        active: line?.hasTest == true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ActivityCard(
                        icon: Icons.task_alt_outlined,
                        label: 'Theo dõi',
                        active: (line?.followupCount ?? 0) > 0,
                        value: (line?.followupCount ?? 0).toString(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: _InfoRow(
                    label: 'Ghi chú',
                    value: note.isEmpty ? 'Chưa có ghi chú' : note,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.icon,
    required this.label,
    required this.active,
    this.value,
  });

  final IconData icon;
  final String label;
  final bool active;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: active ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value ?? (active ? 'Có' : 'Chưa'),
            style: TextStyle(
              color: active ? AppColors.success : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final normalized = (value ?? '').trim();
    if (normalized.isNotEmpty) return normalized;
  }
  return '';
}

String _formatDateTime(String? value) {
  final normalized = (value ?? '').trim();
  if (normalized.isEmpty) return 'Đã check-in';
  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) return normalized;
  final local = parsed.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute · $day/$month';
}

String _gpsText(FieldGps gps) {
  final accuracy = gps.accuracyMeters;
  if (accuracy == null || accuracy <= 0) return 'Đã có GPS';
  return 'Đã có GPS · sai số ${accuracy.round()} m';
}

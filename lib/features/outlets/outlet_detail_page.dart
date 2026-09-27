import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_data_client.dart';
import '../../shared/widgets/app_card.dart';

class OutletDetailPage extends StatefulWidget {
  const OutletDetailPage({
    required this.routeName,
    super.key,
    this.customer,
    this.outlet,
    this.line,
    this.onCheckIn,
  });

  final String routeName;
  final FieldRouteCustomer? customer;
  final FieldOutlet? outlet;
  final FieldDayLine? line;
  final Future<void> Function(FieldDayLine line)? onCheckIn;

  @override
  State<OutletDetailPage> createState() => _OutletDetailPageState();
}

class _OutletDetailPageState extends State<OutletDetailPage> {
  bool _history = false;
  bool _checkingIn = false;
  late bool _checkedIn;
  String? _checkinAt;

  @override
  void initState() {
    super.initState();
    _checkedIn = widget.line?.checkedIn == true;
    _checkinAt = widget.line?.checkinAt;
  }

  Future<void> _checkIn() async {
    final line = widget.line;
    final action = widget.onCheckIn;
    if (line == null || action == null || _checkedIn || _checkingIn) return;

    setState(() {
      _checkingIn = true;
    });
    try {
      await action(line);
      if (!mounted) return;
      setState(() {
        _checkedIn = true;
        _checkinAt = DateTime.now().toIso8601String();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã check-in điểm bán.')),
      );
    } on FieldDataFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không check-in được. Vui lòng thử lại.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _checkingIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final customer = widget.customer;
    final outlet = widget.outlet;
    final name =
        line?.accountName ??
        customer?.accountName ??
        outlet?.name ??
        'Điểm bán';
    final area =
        line?.area ?? customer?.area ?? outlet?.area ?? 'Chưa có khu vực';
    final phone = (line?.phone ?? outlet?.phone ?? '').trim();
    final address = (line?.address ?? outlet?.address ?? '').trim();
    final contact = (customer?.contactName ?? '').trim();
    final note = _firstNonEmpty([line?.note, customer?.note, outlet?.note]);
    final accountId = (customer?.accountId ?? outlet?.code ?? '').trim();
    final visited = line?.status == 'visited';
    final gps = customer?.gps ?? outlet?.gps;
    final canCheckIn =
        line?.sessionCustomerId != null && widget.onCheckIn != null;

    return Scaffold(
      key: const Key('outlet-detail-screen'),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: 220,
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
            child: Stack(
              children: [
                Positioned(
                  right: -22,
                  bottom: -36,
                  child: Icon(
                    Icons.storefront_rounded,
                    size: 180,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                SafeArea(
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
                        const Spacer(),
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            StatusPill(
                              label: _checkedIn
                                  ? 'Đã check-in'
                                  : visited
                                  ? 'Đã ghé'
                                  : 'Chưa ghé',
                              icon: _checkedIn
                                  ? Icons.location_on_rounded
                                  : visited
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.schedule_rounded,
                              backgroundColor: _checkedIn || visited
                                  ? AppColors.successSoft
                                  : const Color(0x26FFFFFF),
                              foregroundColor: _checkedIn || visited
                                  ? AppColors.success
                                  : Colors.white,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(
                              child: Text(
                                _heroPlace(area, gps),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFD8E8FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TabButton(
                    label: 'Thông tin',
                    selected: !_history,
                    onTap: () => setState(() => _history = false),
                  ),
                ),
                Expanded(
                  child: _TabButton(
                    label: 'Lịch sử',
                    selected: _history,
                    onTap: () => setState(() => _history = true),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _history
                ? _HistoryBody(
                    line: line,
                    checkedIn: _checkedIn,
                    checkinAt: _checkinAt,
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      if (line != null && !_checkedIn) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const Key('outlet-checkin-button'),
                            onPressed: canCheckIn && !_checkingIn
                                ? _checkIn
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.success,
                              minimumSize: const Size.fromHeight(48),
                            ),
                            icon: _checkingIn
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.location_on_rounded),
                            label: Text(
                              _checkingIn
                                  ? 'Đang xác nhận vị trí...'
                                  : canCheckIn
                                  ? 'Check-in điểm bán'
                                  : 'Bắt đầu tuyến để check-in',
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
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
                            if ((outlet?.routeName ?? '').isNotEmpty) ...[
                              const Divider(height: 22),
                              _InfoRow(
                                label: 'Tuyến',
                                value: outlet!.routeName,
                              ),
                            ],
                            const Divider(height: 22),
                            _InfoRow(
                              label: 'Địa chỉ',
                              value: address.isEmpty
                                  ? 'Chưa có địa chỉ'
                                  : address,
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
                      if (line != null) ...[
                        const Text(
                          'Tác nghiệp tại điểm bán',
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
                                active: line.hasOrder,
                                accent: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _ActivityCard(
                                icon: Icons.assignment_outlined,
                                label: 'Báo cáo',
                                active: line.hasReport,
                                accent: AppColors.warning,
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
                                active: line.hasTest,
                                accent: const Color(0xFF805AD5),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _ActivityCard(
                                icon: Icons.task_alt_outlined,
                                label: 'Theo dõi',
                                active: line.followupCount > 0,
                                value: line.followupCount.toString(),
                                accent: AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ] else
                        AppCard(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.route_outlined,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Đây là hồ sơ tra cứu. Check-in và tác nghiệp chỉ thực hiện khi mở điểm bán từ Đi tuyến.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
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

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({
    required this.line,
    required this.checkedIn,
    required this.checkinAt,
  });

  final FieldDayLine? line;
  final bool checkedIn;
  final String? checkinAt;

  @override
  Widget build(BuildContext context) {
    if (line == null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.history_rounded,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Lịch sử tác nghiệp sẽ hiển thị khi điểm bán có dữ liệu phiên đi tuyến.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hôm nay',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _InfoRow(
                label: 'Trạng thái',
                value: line?.status == 'visited' ? 'Đã ghé' : 'Chưa hoàn tất',
              ),
              const Divider(height: 22),
              _InfoRow(
                label: 'Check-in',
                value: checkedIn ? _formatDateTime(checkinAt) : 'Chưa check-in',
              ),
              const Divider(height: 22),
              _InfoRow(
                label: 'Đơn hàng',
                value: line?.hasOrder == true ? 'Đã ghi nhận' : 'Chưa có',
              ),
              const Divider(height: 22),
              _InfoRow(
                label: 'Báo cáo',
                value: line?.hasReport == true ? 'Đã ghi nhận' : 'Chưa có',
              ),
            ],
          ),
        ),
      ],
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
    required this.accent,
    this.value,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color accent;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value ?? (active ? 'Đã có' : 'Chưa có'),
            style: TextStyle(
              color: active ? AppColors.success : AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
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

String _heroPlace(String area, FieldGps? gps) {
  if (gps == null) return area;
  final accuracy = gps.accuracyMeters;
  if (accuracy == null || accuracy <= 0) return '$area · Đã có GPS';
  return '$area · GPS ±${accuracy.round()} m';
}

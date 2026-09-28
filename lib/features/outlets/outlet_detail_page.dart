import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_data_client.dart';
import '../../core/media/outlet_media_client.dart';
import '../../core/media/outlet_photo_picker.dart';
import '../../shared/widgets/app_card.dart';
import 'outlet_photo_section.dart';

class OutletDetailPage extends StatefulWidget {
  const OutletDetailPage({
    required this.routeName,
    super.key,
    this.customer,
    this.outlet,
    this.line,
    this.sessionId,
    this.mediaClient,
    this.photoPicker,
    this.onSetCheckIn,
    this.onSkip,
    this.onCreateOrder,
    this.onCustomerOnboarding,
    this.onCreateReport,
    this.onCreateProductTrial,
    this.onCreateFollowup,
  });

  final String routeName;
  final FieldRouteCustomer? customer;
  final FieldOutlet? outlet;
  final FieldDayLine? line;
  final String? sessionId;
  final OutletMediaClient? mediaClient;
  final OutletPhotoPicker? photoPicker;
  final Future<bool> Function(FieldDayLine line, bool checkedIn)? onSetCheckIn;
  final Future<bool> Function(
    FieldDayLine line,
    String reason,
    String note,
  )?
  onSkip;
  final Future<void> Function()? onCreateOrder;
  final Future<void> Function()? onCustomerOnboarding;
  final Future<void> Function()? onCreateReport;
  final Future<void> Function()? onCreateProductTrial;
  final Future<void> Function()? onCreateFollowup;

  @override
  State<OutletDetailPage> createState() => _OutletDetailPageState();
}

class _OutletDetailPageState extends State<OutletDetailPage> {
  bool _history = false;
  bool _checkingIn = false;
  bool _skipping = false;
  late bool _checkedIn;
  late String _visitStatus;
  String? _checkinAt;
  String? _heroPhotoUrl;
  Uint8List? _heroPhotoBytes;

  @override
  void initState() {
    super.initState();
    _checkedIn = widget.line?.checkedIn == true;
    _visitStatus = widget.line?.status ?? 'pending';
    _checkinAt = widget.line?.checkinAt;
  }

  Future<void> _toggleCheckIn() async {
    final line = widget.line;
    final action = widget.onSetCheckIn;
    if (line == null || action == null || _checkingIn) return;

    final nextCheckedIn = !_checkedIn;
    setState(() {
      _checkingIn = true;
    });
    try {
      final saved = await action(line, nextCheckedIn);
      if (!mounted || !saved) return;
      setState(() {
        _checkedIn = nextCheckedIn;
        _checkinAt = nextCheckedIn ? DateTime.now().toIso8601String() : null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextCheckedIn
                ? 'Đã check-in điểm bán.'
                : 'Đã hoàn tác check-in điểm bán.',
          ),
        ),
      );
    } on FieldDataFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextCheckedIn
                ? 'Không check-in được. Vui lòng thử lại.'
                : 'Không hoàn tác check-in được. Vui lòng thử lại.',
          ),
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

  Future<void> _skipVisit() async {
    final line = widget.line;
    final action = widget.onSkip;
    if (line == null ||
        action == null ||
        _skipping ||
        _visitStatus == 'skipped') {
      return;
    }

    final input = await showDialog<_SkipVisitInput>(
      context: context,
      builder: (context) => const _SkipVisitDialog(),
    );
    if (input == null || !mounted) return;

    setState(() {
      _skipping = true;
    });
    try {
      final saved = await action(line, input.reason, input.note);
      if (!mounted || !saved) return;
      setState(() {
        _visitStatus = 'skipped';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã ghi nhận bỏ qua điểm bán.')),
      );
    } on FieldDataFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _skipping = false;
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
    final visited = _visitStatus == 'visited';
    final skipped = _visitStatus == 'skipped';
    final gps = customer?.gps ?? outlet?.gps;
    final routeCustomerId =
        (line?.routeCustomerId ?? customer?.id ?? outlet?.id ?? '').trim();
    final canCheckIn =
        line?.sessionCustomerId != null && widget.onSetCheckIn != null;
    final canSkip =
        line?.sessionCustomerId != null && widget.onSkip != null && !skipped;
    final linkedToCompany =
        (outlet?.coreCustomerId ?? '').trim().isNotEmpty &&
        (outlet?.coreCustomerAddressId ?? '').trim().isNotEmpty;

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
                if (_heroPhotoBytes == null &&
                    (_heroPhotoUrl ?? '').isEmpty) ...[
                  Positioned.fill(
                    key: const Key('outlet-hero-blue-overlay'),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primaryDeep.withValues(alpha: 0.46),
                            AppColors.primaryDeep.withValues(alpha: 0.92),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -22,
                    bottom: -36,
                    child: Icon(
                      Icons.storefront_rounded,
                      size: 180,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ],
                if (_heroPhotoBytes != null)
                  Positioned.fill(
                    key: const Key('outlet-hero-photo-preview'),
                    child: Image.memory(
                      _heroPhotoBytes!,
                      fit: BoxFit.cover,
                    ),
                  )
                else if ((_heroPhotoUrl ?? '').isNotEmpty)
                  Positioned.fill(
                    key: const Key('outlet-hero-photo-preview'),
                    child: Image.network(
                      _heroPhotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
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
                              label: skipped
                                  ? 'Bỏ qua'
                                  : _checkedIn
                                  ? 'Đã check-in'
                                  : visited
                                  ? 'Đã ghé'
                                  : 'Chờ ghé',
                              icon: skipped
                                  ? Icons.skip_next_rounded
                                  : _checkedIn
                                  ? Icons.location_on_rounded
                                  : visited
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.schedule_rounded,
                              backgroundColor: skipped
                                  ? AppColors.warning.withValues(alpha: 0.18)
                                  : _checkedIn || visited
                                  ? AppColors.successSoft
                                  : const Color(0x26FFFFFF),
                              foregroundColor: skipped
                                  ? AppColors.warning
                                  : _checkedIn || visited
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
                      if (line != null && (canCheckIn || canSkip)) ...[
                        if (canCheckIn)
                          SizedBox(
                            width: double.infinity,
                            child: _checkedIn
                                ? OutlinedButton.icon(
                                    key: const Key('outlet-checkin-button'),
                                    onPressed: _checkingIn
                                        ? null
                                        : _toggleCheckIn,
                                    icon: _checkingIn
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.undo_rounded,
                                          ),
                                    label: Text(
                                      _checkingIn
                                          ? 'Đang lưu...'
                                          : 'Hoàn tác check-in',
                                    ),
                                  )
                                : FilledButton.icon(
                                    key: const Key('outlet-checkin-button'),
                                    onPressed: _checkingIn
                                        ? null
                                        : _toggleCheckIn,
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
                                        : const Icon(
                                            Icons.location_on_rounded,
                                          ),
                                    label: Text(
                                      _checkingIn
                                          ? 'Đang xác nhận vị trí...'
                                          : 'Check-in điểm bán',
                                    ),
                                  ),
                          ),
                        if (canCheckIn && canSkip)
                          const SizedBox(height: AppSpacing.sm),
                        if (canSkip)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              key: const Key('outlet-skip-button'),
                              onPressed: _skipping ? null : _skipVisit,
                              icon: _skipping
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.skip_next_rounded),
                              label: Text(
                                _skipping
                                    ? 'Đang lưu...'
                                    : 'Bỏ qua / không mua',
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
                      if (outlet != null &&
                          widget.onCustomerOnboarding != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    linkedToCompany
                                        ? Icons.verified_rounded
                                        : Icons.link_rounded,
                                    color: linkedToCompany
                                        ? AppColors.success
                                        : AppColors.warning,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Liên kết khách Công Ty',
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          linkedToCompany
                                              ? 'Đã sẵn sàng dùng thông tin khách Công Ty.'
                                              : 'Mở hoặc liên kết mã trước khi ra đơn.',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  key: const Key(
                                    'outlet-customer-onboarding',
                                  ),
                                  onPressed: widget.onCustomerOnboarding,
                                  icon: Icon(
                                    linkedToCompany
                                        ? Icons.sync_rounded
                                        : Icons.how_to_reg_outlined,
                                  ),
                                  label: Text(
                                    linkedToCompany
                                        ? 'Xem trạng thái liên kết'
                                        : 'Mở / liên kết mã',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (routeCustomerId.isNotEmpty &&
                          widget.mediaClient != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        OutletPhotoSection(
                          routeCustomerId: routeCustomerId,
                          customerName: name,
                          sessionId: widget.sessionId,
                          mediaClient: widget.mediaClient!,
                          photoPicker:
                              widget.photoPicker ?? DeviceOutletPhotoPicker(),
                          onProfileChanged: (profile) {
                            final hero = profile.media.isEmpty
                                ? null
                                : profile.media.first.viewUrl;
                            if (!mounted) return;
                            setState(() {
                              _heroPhotoUrl = hero;
                              _heroPhotoBytes = null;
                            });
                          },
                          onDraftPreviewChanged: (bytes) {
                            if (!mounted) return;
                            setState(() {
                              _heroPhotoBytes = bytes;
                            });
                          },
                        ),
                      ],
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
                                key: const Key('outlet-create-order'),
                                icon: Icons.receipt_long_outlined,
                                label: 'Đơn hàng',
                                active: line.hasOrder,
                                accent: AppColors.primary,
                                onTap: widget.onCreateOrder,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _ActivityCard(
                                key: const Key('outlet-create-report'),
                                icon: Icons.assignment_outlined,
                                label: 'Báo cáo',
                                active: line.hasReport,
                                accent: AppColors.warning,
                                onTap: widget.onCreateReport,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: _ActivityCard(
                                key: const Key('outlet-create-product-trial'),
                                icon: Icons.science_outlined,
                                label: 'Thử sản phẩm',
                                active: line.hasTest,
                                accent: const Color(0xFF805AD5),
                                onTap: widget.onCreateProductTrial,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _ActivityCard(
                                key: const Key('outlet-create-followup'),
                                icon: Icons.task_alt_outlined,
                                label: 'Theo dõi',
                                active: line.followupCount > 0,
                                value: line.followupCount.toString(),
                                accent: AppColors.danger,
                                onTap: widget.onCreateFollowup,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        if (widget.onCreateOrder != null) ...[
                          const Text(
                            'Bán hàng',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              key: const Key('outlet-directory-create-order'),
                              onPressed: widget.onCreateOrder,
                              icon: const Icon(Icons.receipt_long_outlined),
                              label: const Text('Ra đơn hàng'),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
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
                                  'Check-in, báo cáo, thử sản phẩm và công việc theo dõi thực hiện khi mở điểm bán từ Đi tuyến.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _SkipVisitInput {
  const _SkipVisitInput({
    required this.reason,
    required this.note,
  });

  final String reason;
  final String note;
}

class _SkipVisitDialog extends StatefulWidget {
  const _SkipVisitDialog();

  @override
  State<_SkipVisitDialog> createState() => _SkipVisitDialogState();
}

class _SkipVisitDialogState extends State<_SkipVisitDialog> {
  final _noteController = TextEditingController();
  String? _reason;
  String? _message;

  static const _reasons = <(String, String)>[
    ('closed', 'Đóng cửa'),
    ('busy', 'Khách bận'),
    ('no_demand', 'Không nhu cầu'),
    ('price', 'Chê giá'),
    ('competitor', 'Đang dùng đối thủ'),
    ('stock_enough', 'Còn tồn hàng'),
    ('other', 'Khác'),
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = (_reason ?? '').trim();
    if (reason.isEmpty) {
      setState(() {
        _message = 'Cần chọn lý do bỏ qua điểm bán.';
      });
      return;
    }
    Navigator.of(context).pop(
      _SkipVisitInput(
        reason: reason,
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bỏ qua / không mua'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chọn lý do chính theo nghiệp vụ tuyến. Có thể ghi chú thêm khi cần.',
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: _reasons
                  .map((item) {
                    return ChoiceChip(
                      key: Key('outlet-skip-reason-${item.$1}'),
                      label: Text(item.$2),
                      selected: _reason == item.$1,
                      onSelected: (_) {
                        setState(() {
                          _reason = item.$1;
                          _message = null;
                        });
                      },
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('outlet-skip-note'),
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Ghi chú',
                hintText: 'Ví dụ: khách còn tồn nhiều, hẹn tuần sau quay lại',
              ),
            ),
            if ((_message ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _message!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: const Key('outlet-skip-submit'),
          onPressed: _submit,
          child: const Text('Lưu'),
        ),
      ],
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
              const Divider(height: 22),
              _InfoRow(
                label: 'Thử sản phẩm',
                value: line?.hasTest == true ? 'Đã ghi nhận' : 'Chưa có',
              ),
              const Divider(height: 22),
              _InfoRow(
                label: 'Việc theo dõi',
                value: (line?.followupCount ?? 0) > 0
                    ? '${line!.followupCount} việc'
                    : 'Chưa có',
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
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.accent,
    this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color accent;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AppCard(
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
              value ??
                  (active
                      ? 'Đã có'
                      : onTap == null
                      ? 'Chưa có'
                      : 'Mở'),
              style: TextStyle(
                color: active
                    ? AppColors.success
                    : onTap == null
                    ? AppColors.textSecondary
                    : accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/customer_boundary_client.dart';
import '../../core/sync/customer_boundary_sync.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_page_header.dart';

enum CustomerOnboardingFilter {
  all,
  notSubmitted,
  processing,
  ready,
  attention,
}

class CustomerOnboardingPage extends StatefulWidget {
  const CustomerOnboardingPage({
    required this.client,
    super.key,
    this.focusRouteCustomerId,
    this.submissionService,
    this.onChanged,
    this.pendingRouteCustomerIds = const <String>{},
    this.onRetryProfileSync,
  });

  final CustomerBoundaryClient client;
  final String? focusRouteCustomerId;
  final CustomerBoundarySubmissionService? submissionService;
  final Future<void> Function()? onChanged;
  final Set<String> pendingRouteCustomerIds;
  final Future<void> Function()? onRetryProfileSync;

  @override
  State<CustomerOnboardingPage> createState() => _CustomerOnboardingPageState();
}

class _CustomerOnboardingPageState extends State<CustomerOnboardingPage> {
  List<CustomerVerificationItem> _items = const [];
  CustomerOnboardingFilter _filter = CustomerOnboardingFilter.all;
  String _query = '';
  String? _message;
  String? _busyKey;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final items = await widget.client.loadVerifications();
      if (!mounted) return;
      setState(() {
        _items = _sortItems(items);
      });
    } on CustomerBoundaryFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _message = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _retryProfileSync() async {
    final retry = widget.onRetryProfileSync;
    if (retry == null || _busyKey != null) return;
    setState(() {
      _busyKey = 'profile-sync';
      _message = null;
    });
    try {
      await retry();
      await _load();
    } finally {
      if (mounted) {
        setState(() {
          _busyKey = null;
        });
      }
    }
  }

  List<CustomerVerificationItem> _sortItems(
    List<CustomerVerificationItem> items,
  ) {
    final focus = (widget.focusRouteCustomerId ?? '').trim();
    final sorted = [...items];
    sorted.sort((left, right) {
      if (focus.isNotEmpty) {
        final leftFocus = left.routeCustomerId == focus;
        final rightFocus = right.routeCustomerId == focus;
        if (leftFocus != rightFocus) return leftFocus ? -1 : 1;
      }
      return left.customerName.toLowerCase().compareTo(
        right.customerName.toLowerCase(),
      );
    });
    return sorted;
  }

  Future<void> _mutate(
    CustomerVerificationItem item, {
    required bool submit,
  }) async {
    if (_busyKey != null) return;
    final operation = submit
        ? 'customer-verification.submit'
        : 'customer-verification.sync';
    final signature = '$operation:${item.routeCustomerId}';
    final service = widget.submissionService;

    setState(() {
      _busyKey = signature;
      _message = null;
    });
    try {
      if (service == null) {
        throw const CustomerBoundaryFailure(
          code: 'CUSTOMER_SYNC_UNAVAILABLE',
          message: 'Chưa sẵn sàng gửi thông tin điểm bán. Vui lòng thử lại.',
        );
      }
      final result = submit
          ? await service.submit(routeCustomerId: item.routeCustomerId)
          : await service.sync(routeCustomerId: item.routeCustomerId);
      if (result.status == CustomerBoundarySubmitStatus.completed) {
        await _load();
        await widget.onChanged?.call();
      }
      if (!mounted) return;
      setState(() {
        _message = result.status == CustomerBoundarySubmitStatus.queued
            ? 'Đã lưu thao tác chờ gửi. Ứng dụng sẽ tự đồng bộ lại.'
            : submit
            ? 'Đã gửi điểm bán sang Công Ty để xác minh.'
            : 'Đã cập nhật trạng thái từ Công Ty.';
      });
    } on CustomerBoundaryFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _message = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busyKey = null;
        });
      }
    }
  }

  List<CustomerVerificationItem> get _visibleItems {
    final query = _query.trim().toLowerCase();
    return _items
        .where((item) {
          if (!_matchesFilter(item.status, _filter)) return false;
          if (query.isEmpty) return true;
          return [
            item.customerName,
            item.phone,
            item.address,
            item.area,
            item.routeName,
            item.coreCustomerCode,
          ].whereType<String>().any(
            (value) => value.toLowerCase().contains(query),
          );
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems;
    return Scaffold(
      key: const Key('customer-onboarding-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: 'Mở / liên kết mã',
            subtitle: 'Xác minh điểm bán với Công Ty',
            leading: IconButton(
              onPressed: _busyKey == null
                  ? () => Navigator.of(context).pop()
                  : null,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                children: [
                  if (_loading) const LinearProgressIndicator(minHeight: 2),
                  if ((_message ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _Notice(message: _message!),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    key: const Key('customer-onboarding-search'),
                    onChanged: (value) {
                      setState(() {
                        _query = value;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Tìm điểm bán, mã, điện thoại...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: CustomerOnboardingFilter.values
                          .map(
                            (filter) => Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.xs,
                              ),
                              child: ChoiceChip(
                                key: Key('customer-filter-${filter.name}'),
                                label: Text(_filterLabel(filter)),
                                selected: _filter == filter,
                                onSelected: (_) {
                                  setState(() {
                                    _filter = filter;
                                  });
                                },
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (!_loading && items.isEmpty)
                    const AppCard(
                      child: EmptyState(
                        icon: Icons.how_to_reg_outlined,
                        title: 'Chưa có điểm bán phù hợp',
                        message: 'Thử đổi trạng thái hoặc từ khóa tìm kiếm.',
                      ),
                    )
                  else
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _VerificationCard(
                          item: item,
                          busy: _busyKey != null,
                          pendingProfile: widget.pendingRouteCustomerIds
                              .contains(item.routeCustomerId),
                          onSubmit: () => _mutate(item, submit: true),
                          onSync: () => _mutate(item, submit: false),
                          onRetryProfileSync: widget.onRetryProfileSync == null
                              ? null
                              : _retryProfileSync,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({
    required this.item,
    required this.busy,
    required this.onSubmit,
    required this.onSync,
    required this.pendingProfile,
    this.onRetryProfileSync,
  });

  final CustomerVerificationItem item;
  final bool busy;
  final bool pendingProfile;
  final VoidCallback onSubmit;
  final VoidCallback onSync;
  final VoidCallback? onRetryProfileSync;

  @override
  Widget build(BuildContext context) {
    final canSubmit = (item.address ?? '').trim().isNotEmpty;
    final submitted = item.status != 'not_submitted';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.customerName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [item.routeName, item.area]
                          .whereType<String>()
                          .where((value) => value.isNotEmpty)
                          .join(' · '),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: item.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoLine(
            label: 'Điện thoại',
            value: (item.phone ?? '').isEmpty ? 'Chưa có' : item.phone!,
          ),
          const Divider(height: 20),
          _InfoLine(
            label: 'Địa chỉ',
            value: (item.address ?? '').isEmpty
                ? 'Chưa có địa chỉ'
                : item.address!,
          ),
          const Divider(height: 20),
          _InfoLine(
            label: 'Mã Công Ty',
            value: (item.coreCustomerCode ?? '').isNotEmpty
                ? item.coreCustomerCode!
                : 'Chưa có',
          ),
          if ((item.reviewReason ?? '').isNotEmpty) ...[
            const Divider(height: 20),
            _InfoLine(label: 'Phản hồi', value: item.reviewReason!),
          ],
          const SizedBox(height: AppSpacing.md),
          if (!submitted)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: Key('customer-submit-${item.routeCustomerId}'),
                onPressed: busy || !canSubmit ? null : onSubmit,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  busy ? 'Đang gửi...' : 'Gửi xác minh / mở mã',
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: Key('customer-sync-${item.routeCustomerId}'),
                onPressed: busy || (item.coreRequestId ?? '').isEmpty
                    ? null
                    : onSync,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
                label: Text(
                  busy ? 'Đang cập nhật...' : 'Cập nhật trạng thái',
                ),
              ),
            ),
          if (!canSubmit && !submitted) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              pendingProfile
                  ? 'Thông tin điểm bán vừa bổ sung đang chờ đồng bộ. Đồng bộ xong hệ thống sẽ tự kiểm tra lại.'
                  : 'Cần bổ sung địa chỉ điểm bán trước khi gửi.',
              key: Key('customer-profile-warning-${item.routeCustomerId}'),
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (pendingProfile && onRetryProfileSync != null) ...[
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: Key('customer-profile-sync-${item.routeCustomerId}'),
                  onPressed: busy ? null : onRetryProfileSync,
                  icon: const Icon(Icons.sync_rounded),
                  label: Text(busy ? 'Đang đồng bộ...' : 'Đồng bộ lại thông tin'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final ready = const {'approved', 'linked_existing'}.contains(status);
    final attention = const {'rejected', 'cancelled'}.contains(status);
    final color = ready
        ? AppColors.success
        : attention
        ? AppColors.danger
        : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        customerVerificationStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
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
          width: 92,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String customerVerificationStatusLabel(String status) {
  return switch (status) {
    'not_submitted' => 'Chưa gửi',
    'submitted' => 'Đã gửi Công Ty',
    'under_review' => 'Đang xác minh',
    'need_more_info' => 'Cần bổ sung',
    'approved' => 'Đã mở mã',
    'linked_existing' => 'Đã liên kết',
    'rejected' => 'Bị từ chối',
    'cancelled' => 'Đã hủy',
    _ => 'Đang xử lý',
  };
}

bool _matchesFilter(
  String status,
  CustomerOnboardingFilter filter,
) {
  return switch (filter) {
    CustomerOnboardingFilter.all => true,
    CustomerOnboardingFilter.notSubmitted => status == 'not_submitted',
    CustomerOnboardingFilter.processing => const {
      'submitted',
      'under_review',
      'need_more_info',
    }.contains(status),
    CustomerOnboardingFilter.ready => const {
      'approved',
      'linked_existing',
    }.contains(status),
    CustomerOnboardingFilter.attention => const {
      'rejected',
      'cancelled',
    }.contains(status),
  };
}

String _filterLabel(CustomerOnboardingFilter filter) {
  return switch (filter) {
    CustomerOnboardingFilter.all => 'Tất cả',
    CustomerOnboardingFilter.notSubmitted => 'Chưa gửi',
    CustomerOnboardingFilter.processing => 'Đang xử lý',
    CustomerOnboardingFilter.ready => 'Đã mở / liên kết',
    CustomerOnboardingFilter.attention => 'Cần chú ý',
  };
}

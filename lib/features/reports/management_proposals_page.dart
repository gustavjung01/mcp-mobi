import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/management_proposal_client.dart';
import '../../core/sync/management_proposal_sync.dart';
import '../../core/sync/mutation_queue.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_page_header.dart';

class ManagementProposalsPage extends StatefulWidget {
  const ManagementProposalsPage({
    required this.client,
    required this.submissionService,
    required this.syncService,
    required this.queue,
    super.key,
  });

  final ManagementProposalClient client;
  final ManagementProposalSubmissionService submissionService;
  final ManagementProposalSyncService syncService;
  final MutationQueueStore queue;

  @override
  State<ManagementProposalsPage> createState() =>
      _ManagementProposalsPageState();
}

class _ManagementProposalsPageState extends State<ManagementProposalsPage> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _entityLabel = TextEditingController();
  final _impact = TextEditingController();
  final _reason = TextEditingController();
  final _rule = TextEditingController();
  final _evidence = TextEditingController();

  List<ManagementProposal> _items = const [];
  List<QueuedMutation> _pending = const [];
  bool _loading = true;
  bool _saving = false;
  bool _detailsExpanded = false;
  String _priority = 'normal';
  String _entityType = 'other';
  String? _message;

  @override
  void initState() {
    super.initState();
    _refresh(sync: true);
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _entityLabel.dispose();
    _impact.dispose();
    _reason.dispose();
    _rule.dispose();
    _evidence.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool sync = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _message = null;
      });
    }

    try {
      if (sync) await widget.syncService.syncPending();
      final results = await Future.wait<Object>([
        widget.client.load(),
        widget.queue.load(operations: ManagementProposalSyncService.operations),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<ManagementProposal>;
        _pending = (results[1] as List<QueuedMutation>)
            .where((item) => item.isOutstanding)
            .toList(growable: false)
            .reversed
            .toList(growable: false);
      });
    } on ManagementProposalFailure catch (failure) {
      if (!mounted) return;
      setState(() => _message = failure.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = 'Không tải được danh sách Đề xuất. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _evidenceLines(String raw) {
    return raw
        .split(RegExp(r'[\r\n]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty || _content.text.trim().isEmpty) {
      setState(() => _message = 'Cần nhập tiêu đề và nội dung đề xuất.');
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final result = await widget.submissionService.create(
        ManagementProposalDraft(
          title: _title.text,
          content: _content.text,
          entityType: _entityType,
          entityLabel: _entityLabel.text,
          impact: _impact.text,
          reason: _reason.text,
          rule: _rule.text,
          evidence: _evidenceLines(_evidence.text),
          priority: _priority,
        ),
      );
      _title.clear();
      _content.clear();
      _entityLabel.clear();
      _impact.clear();
      _reason.clear();
      _rule.clear();
      _evidence.clear();
      _priority = 'normal';
      _entityType = 'other';
      _detailsExpanded = false;
      await _refresh(sync: false);
      if (!mounted) return;
      setState(() {
        _message = result.status == ManagementProposalSubmitStatus.completed
            ? 'Đã gửi Đề xuất.'
            : 'Đã lưu Đề xuất chờ gửi. Ứng dụng sẽ tự đồng bộ lại.';
      });
    } on ManagementProposalFailure catch (failure) {
      if (!mounted) return;
      setState(() => _message = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resubmit(ManagementProposal proposal) async {
    final input = await showDialog<_ResubmitInput>(
      context: context,
      builder: (context) => _ResubmitDialog(proposal: proposal),
    );
    if (input == null || !mounted) return;

    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final result = await widget.submissionService.resubmit(
        proposalId: proposal.id,
        content: input.content,
        reason: input.reason,
        evidence: input.evidence,
      );
      await _refresh(sync: false);
      if (!mounted) return;
      setState(() {
        _message = result.status == ManagementProposalSubmitStatus.completed
            ? 'Đã gửi nội dung bổ sung.'
            : 'Đã lưu nội dung bổ sung chờ gửi.';
      });
    } on ManagementProposalFailure catch (failure) {
      if (!mounted) return;
      setState(() => _message = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('management-proposals-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: 'Đề xuất',
            subtitle: 'Gửi nội dung cần quản lý xem xét và theo dõi phản hồi',
            leading: IconButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            trailing: IconButton(
              onPressed: _loading || _saving ? null : () => _refresh(sync: true),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refresh(sync: true),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tạo đề xuất mới',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          key: const Key('proposal-title'),
                          controller: _title,
                          decoration: const InputDecoration(
                            labelText: 'Tiêu đề',
                            hintText: 'Nội dung cần quản lý xem xét',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          key: const Key('proposal-content'),
                          controller: _content,
                          minLines: 3,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            labelText: 'Nội dung đề xuất',
                            hintText: 'Nêu rõ tình huống và đề xuất xử lý',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        DropdownButtonFormField<String>(
                          key: const Key('proposal-priority'),
                          initialValue: _priority,
                          decoration: const InputDecoration(
                            labelText: 'Mức ưu tiên',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'normal',
                              child: Text('Bình thường'),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: Text('Cần xử lý sớm'),
                            ),
                            DropdownMenuItem(
                              value: 'critical',
                              child: Text('Ưu tiên cao'),
                            ),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) => setState(
                                    () => _priority = value ?? 'normal',
                                  ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        InkWell(
                          key: const Key('proposal-details-toggle'),
                          onTap: _saving
                              ? null
                              : () => setState(
                                    () => _detailsExpanded = !_detailsExpanded,
                                  ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Thông tin bổ sung',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Icon(
                                  _detailsExpanded
                                      ? Icons.expand_less_rounded
                                      : Icons.expand_more_rounded,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_detailsExpanded) ...[
                          const SizedBox(height: AppSpacing.xs),
                          DropdownButtonFormField<String>(
                            initialValue: _entityType,
                            decoration: const InputDecoration(
                              labelText: 'Liên quan đến',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'outlet',
                                child: Text('Điểm bán'),
                              ),
                              DropdownMenuItem(
                                value: 'route',
                                child: Text('Tuyến'),
                              ),
                              DropdownMenuItem(
                                value: 'customer',
                                child: Text('Khách hàng'),
                              ),
                              DropdownMenuItem(
                                value: 'sales-order',
                                child: Text('Đơn bán hàng'),
                              ),
                              DropdownMenuItem(
                                value: 'other',
                                child: Text('Khác'),
                              ),
                            ],
                            onChanged: _saving
                                ? null
                                : (value) => setState(
                                      () => _entityType = value ?? 'other',
                                    ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _entityLabel,
                            decoration: const InputDecoration(
                              labelText: 'Tên nội dung liên quan',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _impact,
                            decoration: const InputDecoration(
                              labelText: 'Tác động',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _reason,
                            decoration: const InputDecoration(
                              labelText: 'Lý do',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _rule,
                            decoration: const InputDecoration(
                              labelText: 'Quy định hoặc hướng xử lý liên quan',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _evidence,
                            minLines: 2,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'Minh chứng',
                              hintText: 'Mỗi dòng một nội dung hoặc đường dẫn',
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const Key('proposal-submit'),
                            onPressed: _saving ? null : _submit,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_outlined),
                            label: Text(_saving ? 'Đang gửi...' : 'Gửi đề xuất'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if ((_message ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      child: Text(
                        _message!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (_pending.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      'Đang chờ gửi',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ..._pending.map(
                      (mutation) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.schedule_send_outlined,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  mutation.entityLabel.trim().isEmpty
                                      ? 'Đề xuất đang chờ gửi'
                                      : mutation.entityLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Đề xuất của tôi',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_items.isEmpty)
                    const AppCard(
                      child: EmptyState(
                        icon: Icons.lightbulb_outline_rounded,
                        title: 'Chưa có đề xuất',
                        message: 'Các đề xuất đã gửi sẽ hiển thị tại đây.',
                      ),
                    )
                  else
                    ..._items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _ProposalCard(
                          proposal: item,
                          busy: _saving,
                          onResubmit: item.status == 'needs-info'
                              ? () => _resubmit(item)
                              : null,
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

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.busy,
    this.onResubmit,
  });

  final ManagementProposal proposal;
  final bool busy;
  final VoidCallback? onResubmit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: Key('proposal-${proposal.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  proposal.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _statusLabel(proposal.status),
                style: TextStyle(
                  color: _statusColor(proposal.status),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            proposal.content,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (proposal.entityLabel.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Liên quan: ${proposal.entityLabel}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
          if ((proposal.decisionNote ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Phản hồi: ${proposal.decisionNote}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (onResubmit != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onResubmit,
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Bổ sung'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResubmitInput {
  const _ResubmitInput({
    required this.content,
    required this.reason,
    required this.evidence,
  });

  final String content;
  final String reason;
  final List<String> evidence;
}

class _ResubmitDialog extends StatefulWidget {
  const _ResubmitDialog({required this.proposal});

  final ManagementProposal proposal;

  @override
  State<_ResubmitDialog> createState() => _ResubmitDialogState();
}

class _ResubmitDialogState extends State<_ResubmitDialog> {
  late final TextEditingController _content;
  final _reason = TextEditingController();
  final _evidence = TextEditingController();
  String? _message;

  @override
  void initState() {
    super.initState();
    _content = TextEditingController(text: widget.proposal.content);
  }

  @override
  void dispose() {
    _content.dispose();
    _reason.dispose();
    _evidence.dispose();
    super.dispose();
  }

  void _submit() {
    final content = _content.text.trim();
    if (content.isEmpty) {
      setState(() => _message = 'Cần nhập nội dung bổ sung.');
      return;
    }
    Navigator.of(context).pop(
      _ResubmitInput(
        content: content,
        reason: _reason.text.trim(),
        evidence: _evidence.text
            .split(RegExp(r'[\r\n]+'))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bổ sung đề xuất'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _content,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Nội dung'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _reason,
              decoration: const InputDecoration(labelText: 'Lý do bổ sung'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _evidence,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Minh chứng',
                hintText: 'Mỗi dòng một nội dung hoặc đường dẫn',
              ),
            ),
            if ((_message ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _message!,
                style: const TextStyle(color: AppColors.danger),
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
          onPressed: _submit,
          child: const Text('Gửi lại'),
        ),
      ],
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'needs-info' => 'Chờ bổ sung',
    'approved' => 'Đã đồng ý',
    'rejected' => 'Đã từ chối',
    _ => 'Chờ quyết định',
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'approved' => AppColors.success,
    'rejected' => AppColors.danger,
    'needs-info' => AppColors.warning,
    _ => AppColors.primary,
  };
}

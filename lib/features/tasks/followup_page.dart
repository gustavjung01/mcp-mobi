import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_activity_client.dart';
import '../../core/data/field_data_client.dart';
import '../../core/idempotency/canonical_idempotency.dart';
import '../../core/sync/field_activity_sync.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/navy_page_header.dart';

class FollowupPage extends StatefulWidget {
  const FollowupPage({
    required this.line,
    required this.owner,
    required this.submissionService,
    super.key,
  });

  final FieldDayLine line;
  final String owner;
  final FieldActivitySubmissionService submissionService;

  @override
  State<FollowupPage> createState() => _FollowupPageState();
}

class _FollowupPageState extends State<FollowupPage> {
  static const _quickTitles = <String>[
    'Gửi báo giá',
    'Gọi lại',
    'Mang mẫu thử',
    'Chốt đơn sau',
    'Kiểm tra tồn',
    'Nhắc công nợ',
  ];
  static const _priorities = <String, String>{
    'low': 'Thấp',
    'medium': 'Trung bình',
    'high': 'Cao',
    'urgent': 'Khẩn',
  };
  static const _types = <String, String>{
    'general': 'Chung',
    'order': 'Đơn hàng',
    'test': 'Sau khi thử sản phẩm',
    'report': 'Báo cáo',
    'debt': 'Công nợ',
    'delivery': 'Giao hàng',
  };

  final _title = TextEditingController();
  final _owner = TextEditingController();
  final _note = TextEditingController();
  DateTime? _dueDate;
  String _priority = 'medium';
  String _type = 'general';
  bool _saving = false;
  String? _message;
  String? _submissionFingerprint;
  String? _submissionKey;

  @override
  void initState() {
    super.initState();
    _owner.text = widget.owner;
  }

  @override
  void dispose() {
    _title.dispose();
    _owner.dispose();
    _note.dispose();
    super.dispose();
  }

  void _setQuickDate(int days) {
    final now = DateTime.now();
    setState(() {
      _dueDate = DateTime(now.year, now.month, now.day + days);
      _message = null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDate: _dueDate ?? now.add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dueDate = picked;
    });
  }

  Map<String, Object?> _payload() => {
    'sessionCustomerId': widget.line.sessionCustomerId,
    'title': _title.text.trim(),
    if (_dueDate != null) 'dueDate': _dateOnly(_dueDate!),
    'priority': _priority,
    if (_owner.text.trim().isNotEmpty) 'owner': _owner.text.trim(),
    if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
    'followupType': _type,
  };

  Future<void> _submit() async {
    if ((widget.line.sessionCustomerId ?? '').isEmpty) {
      setState(() {
        _message = 'Điểm bán không còn thuộc phiên đi tuyến đang mở.';
      });
      return;
    }
    if (_title.text.trim().isEmpty) {
      setState(() {
        _message = 'Cần nhập nội dung công việc cần theo dõi.';
      });
      return;
    }

    final payload = _payload();
    final fingerprint = jsonEncode(payload);
    if (_submissionFingerprint != fingerprint || _submissionKey == null) {
      _submissionFingerprint = fingerprint;
      _submissionKey = CanonicalIdempotencyKey.create(
        FieldActivityKind.followup.operation,
      );
    }

    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final result = await widget.submissionService.submit(
        kind: FieldActivityKind.followup,
        idempotencyKey: _submissionKey!,
        entityLabel: widget.line.accountName,
        payload: payload,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result.status);
    } on FieldActivityFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _message = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('followup-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: 'Việc cần theo dõi',
            subtitle: widget.line.accountName,
            leading: IconButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                120,
              ),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          widget.line.accountName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Việc cần làm',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: _quickTitles
                      .map(
                        (value) => ActionChip(
                          label: Text(value),
                          onPressed: _saving
                              ? null
                              : () {
                                  setState(() {
                                    _title.text = value;
                                    _message = null;
                                  });
                                },
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const Key('followup-title'),
                  controller: _title,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung công việc',
                    hintText: 'Nhập việc cần theo dõi',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Ngày hẹn',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _setQuickDate(1),
                        child: const Text('Mai'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _setQuickDate(3),
                        child: const Text('3 ngày'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _setQuickDate(7),
                        child: const Text('Tuần sau'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  key: const Key('followup-date'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  tileColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  leading: const Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    _dueDate == null
                        ? 'Chọn ngày hẹn'
                        : _dateOnly(_dueDate!),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _saving ? null : _pickDate,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Mức ưu tiên',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: _priorities.entries
                      .map(
                        (entry) => ChoiceChip(
                          selected: _priority == entry.key,
                          label: Text(entry.value),
                          onSelected: _saving
                              ? null
                              : (_) {
                                  setState(() {
                                    _priority = entry.key;
                                  });
                                },
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  key: const Key('followup-type'),
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Loại công việc',
                  ),
                  items: _types.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _type = value;
                          });
                        },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const Key('followup-owner'),
                  controller: _owner,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Người phụ trách',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const Key('followup-note'),
                  controller: _note,
                  enabled: !_saving,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    hintText: 'Thông tin cần nhớ khi xử lý công việc',
                  ),
                ),
                if ((_message ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      _message!,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: FilledButton.icon(
            key: const Key('followup-submit'),
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
                : const Icon(Icons.task_alt_rounded),
            label: Text(_saving ? 'Đang lưu...' : 'Lưu việc theo dõi'),
          ),
        ),
      ),
    );
  }
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return value.year.toString() + '-' + month + '-' + day;
}

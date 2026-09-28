import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_activity_client.dart';
import '../../core/data/field_data_client.dart';
import '../../core/idempotency/canonical_idempotency.dart';
import '../../core/sync/field_activity_sync.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/navy_page_header.dart';

class ProductTrialPage extends StatefulWidget {
  const ProductTrialPage({
    required this.line,
    required this.submissionService,
    super.key,
  });

  final FieldDayLine line;
  final FieldActivitySubmissionService submissionService;

  @override
  State<ProductTrialPage> createState() => _ProductTrialPageState();
}

class _ProductTrialPageState extends State<ProductTrialPage> {
  static const _statuses = <String, String>{
    'tested': 'Đã thử',
    'ok': 'Đạt',
    'interested': 'Quan tâm',
    'sample': 'Đã gửi mẫu',
    'follow': 'Cần theo dõi',
    'retry': 'Thử lại',
    'bad': 'Chưa đạt',
  };
  static const _quickNotes = <String>[
    'Khách muốn thử',
    'Gửi mẫu',
    'Test vị mới',
    'Đạt',
    'Chưa đạt',
    'Báo giá sau khi thử',
  ];

  final _product = TextEditingController();
  final _note = TextEditingController();
  final Set<String> _selectedQuickNotes = {};
  String _status = 'tested';
  bool _saving = false;
  String? _message;
  String? _submissionFingerprint;
  String? _submissionKey;

  @override
  void dispose() {
    _product.dispose();
    _note.dispose();
    super.dispose();
  }

  void _toggleQuickNote(String value) {
    setState(() {
      if (!_selectedQuickNotes.add(value)) {
        _selectedQuickNotes.remove(value);
      }
    });
  }

  Map<String, Object?> _payload() {
    final note = <String>[
      ..._selectedQuickNotes,
      if (_note.text.trim().isNotEmpty) _note.text.trim(),
    ].join(', ');
    return {
      'sessionCustomerId': widget.line.sessionCustomerId,
      'fileTitle': 'Kết quả thử sản phẩm trong phiên',
      'results': [
        {
          'productName': _product.text.trim(),
          'status': _status,
          if (note.isNotEmpty) 'note': note,
        },
      ],
      if (note.isNotEmpty) 'note': note,
      'customerStatus': 'tested',
    };
  }

  Future<void> _submit() async {
    if ((widget.line.sessionCustomerId ?? '').isEmpty) {
      setState(() {
        _message = 'Điểm bán không còn thuộc phiên đi tuyến đang mở.';
      });
      return;
    }
    if (_product.text.trim().isEmpty) {
      setState(() {
        _message = 'Cần nhập sản phẩm được thử.';
      });
      return;
    }

    final payload = _payload();
    final fingerprint = jsonEncode(payload);
    if (_submissionFingerprint != fingerprint || _submissionKey == null) {
      _submissionFingerprint = fingerprint;
      _submissionKey = CanonicalIdempotencyKey.create(
        FieldActivityKind.productTrial.operation,
      );
    }

    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final result = await widget.submissionService.submit(
        kind: FieldActivityKind.productTrial,
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
      key: const Key('product-trial-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: 'Thử sản phẩm',
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
                TextField(
                  key: const Key('product-trial-name'),
                  controller: _product,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Sản phẩm được thử',
                    hintText: 'Nhập tên sản phẩm',
                    prefixIcon: Icon(Icons.science_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Kết quả',
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
                  children: _statuses.entries
                      .map(
                        (entry) => ChoiceChip(
                          selected: _status == entry.key,
                          label: Text(entry.value),
                          onSelected: _saving
                              ? null
                              : (_) {
                                  setState(() {
                                    _status = entry.key;
                                    _message = null;
                                  });
                                },
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Ghi chú nhanh',
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
                  children: _quickNotes
                      .map(
                        (value) => FilterChip(
                          selected: _selectedQuickNotes.contains(value),
                          label: Text(value),
                          onSelected: _saving
                              ? null
                              : (_) => _toggleQuickNote(value),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('product-trial-note'),
                  controller: _note,
                  enabled: !_saving,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    hintText: 'Phản hồi của khách hoặc việc cần lưu ý',
                  ),
                ),
                if ((_message ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _Message(message: _message!),
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
            key: const Key('product-trial-submit'),
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
                : const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Đang lưu...' : 'Lưu kết quả thử'),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
        ),
      ),
    );
  }
}

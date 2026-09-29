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
    this.activityClient,
  });

  final FieldDayLine line;
  final FieldActivitySubmissionService submissionService;
  final FieldActivityClient? activityClient;

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
    'Thử vị mới',
    'Đạt',
    'Chưa đạt',
    'Báo giá sau khi thử',
  ];

  final _product = TextEditingController();
  final _note = TextEditingController();
  final Set<String> _selectedQuickNotes = {};
  List<FieldTestFile> _testFiles = const [];
  String? _selectedFileId;
  String? _selectedProductId;
  String _status = 'tested';
  bool _loadingOptions = true;
  bool _saving = false;
  String? _message;
  String? _submissionFingerprint;
  String? _submissionKey;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final source = widget.activityClient;
    if (source is! FieldActivityReferenceClient) {
      if (mounted) setState(() => _loadingOptions = false);
      return;
    }
    final referenceClient = source as FieldActivityReferenceClient;
    try {
      final files = await referenceClient.loadTestFiles();
      if (!mounted) return;
      setState(() {
        _testFiles = files;
      });
    } on FieldActivityFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _message =
            '${failure.message} Vẫn có thể nhập sản phẩm thử thủ công.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingOptions = false);
      }
    }
  }

  FieldTestFile? get _selectedFile {
    final wanted = (_selectedFileId ?? '').trim();
    if (wanted.isEmpty) return null;
    for (final file in _testFiles) {
      if (file.id == wanted) return file;
    }
    return null;
  }

  FieldTestProduct? get _selectedProduct {
    final wanted = (_selectedProductId ?? '').trim();
    final file = _selectedFile;
    if (wanted.isEmpty || file == null) return null;
    for (final product in file.products) {
      if (product.id == wanted) return product;
    }
    return null;
  }

  void _selectFile(String? fileId) {
    setState(() {
      _selectedFileId = (fileId ?? '').trim().isEmpty ? null : fileId;
      _selectedProductId = null;
      _product.clear();
      _message = null;
    });
  }

  void _selectProduct(FieldTestProduct product) {
    setState(() {
      _selectedProductId = product.id;
      _product.text = product.productName;
      _message = null;
    });
  }

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
    final file = _selectedFile;
    final product = _selectedProduct;
    return {
      'sessionCustomerId': widget.line.sessionCustomerId,
      if (file != null) 'fileId': file.id,
      'fileTitle': file?.title ?? 'Kết quả thử sản phẩm trong phiên',
      'results': [
        {
          if (product != null) 'productId': product.id,
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
        _message = 'Cần chọn hoặc nhập sản phẩm được thử.';
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
                if (_loadingOptions)
                  const LinearProgressIndicator(
                    key: Key('product-trial-options-loading'),
                    minHeight: 2,
                  )
                else if (_testFiles.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    key: const Key('product-trial-file'),
                    initialValue: _selectedFileId ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Phiếu thử sản phẩm',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Không chọn phiếu'),
                      ),
                      ..._testFiles.map(
                        (file) => DropdownMenuItem(
                          value: file.id,
                          child: Text(
                            file.testDate.isEmpty
                                ? file.title
                                : '${file.title} · ${file.testDate}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: _saving ? null : _selectFile,
                  ),
                  if (_selectedFile != null &&
                      _selectedFile!.products.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Sản phẩm trong phiếu',
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
                      children: _selectedFile!.products
                          .map(
                            (product) => ChoiceChip(
                              key: Key(
                                'product-trial-product-${product.id}',
                              ),
                              selected:
                                  _selectedProductId == product.id,
                              label: Text(product.productName),
                              onSelected: _saving
                                  ? null
                                  : (_) => _selectProduct(product),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('product-trial-name'),
                  controller: _product,
                  enabled: !_saving,
                  onChanged: (_) {
                    if (_selectedProductId != null) {
                      setState(() => _selectedProductId = null);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Sản phẩm được thử',
                    hintText: 'Chọn từ phiếu hoặc nhập tên sản phẩm',
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

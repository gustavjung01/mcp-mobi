import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_activity_client.dart';
import '../../core/data/field_data_client.dart';
import '../../core/idempotency/canonical_idempotency.dart';
import '../../core/media/outlet_media_client.dart';
import '../../core/media/outlet_photo_picker.dart';
import '../../core/sync/field_activity_sync.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/navy_page_header.dart';
import '../outlets/outlet_photo_section.dart';

class MarketReportPage extends StatefulWidget {
  const MarketReportPage({
    required this.line,
    required this.routeName,
    required this.routeId,
    required this.sessionDate,
    required this.owner,
    required this.activityClient,
    required this.submissionService,
    super.key,
    this.mediaClient,
    this.photoPicker,
    this.sessionId,
  });

  final FieldDayLine line;
  final String routeName;
  final String routeId;
  final String sessionDate;
  final String owner;
  final String? sessionId;
  final FieldActivityClient activityClient;
  final FieldActivitySubmissionService submissionService;
  final OutletMediaClient? mediaClient;
  final OutletPhotoPicker? photoPicker;

  @override
  State<MarketReportPage> createState() => _MarketReportPageState();
}

class _MarketReportPageState extends State<MarketReportPage> {
  final _price = TextEditingController();
  final _competitor = TextEditingController();
  final _display = TextEditingController();
  final _stock = TextEditingController();
  final _demand = TextEditingController();
  final _opportunity = TextEditingController();
  final _risk = TextEditingController();
  final _nextAction = TextEditingController();
  final _note = TextEditingController();

  static const _quickNotes = <String>[
    'Chê giá',
    'Còn tồn',
    'Cần test',
    'Muốn đổi nguồn',
    'Cần báo giá',
    'Đang dùng đối thủ',
  ];

  List<FieldReportSettingGroup> _groups = const [];
  List<FieldReportTemplate> _templates = const [];
  String? _selectedTemplateId;
  final Set<String> _selectedIds = {};
  final Set<String> _selectedQuickNotes = {};
  List<String> _mediaIds = const [];
  bool _loadingSettings = true;
  bool _loadingTemplates = true;
  bool _saving = false;
  String? _message;
  String? _submissionFingerprint;
  String? _submissionKey;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadTemplates();
  }

  @override
  void dispose() {
    for (final controller in [
      _price,
      _competitor,
      _display,
      _stock,
      _demand,
      _opportunity,
      _risk,
      _nextAction,
      _note,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final groups = await widget.activityClient.loadReportSettings();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _message = null;
      });
    } on FieldActivityFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _message =
            '${failure.message} Vẫn có thể nhập báo cáo bằng nội dung bên dưới.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingSettings = false;
        });
      }
    }
  }

  Future<void> _loadTemplates() async {
    final source = widget.activityClient;
    if (source is! FieldActivityReferenceClient) {
      if (mounted) setState(() => _loadingTemplates = false);
      return;
    }
    final referenceClient = source as FieldActivityReferenceClient;
    try {
      final templates = await referenceClient.loadReportTemplates();
      if (!mounted) return;
      setState(() {
        _templates = templates;
      });
    } on FieldActivityFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _message ??= '${failure.message} Vẫn có thể lập báo cáo thủ công.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingTemplates = false);
      }
    }
  }

  void _applyTemplate(FieldReportTemplate template) {
    setState(() {
      _selectedTemplateId = template.id;
      _price.text = template.priceSummary;
      _competitor.text = template.competitorSummary;
      _display.text = template.displaySummary;
      _stock.text = template.stockSummary;
      _demand.text = template.demandSummary;
      _opportunity.text = template.opportunitySummary;
      _risk.text = template.riskSummary;
      _nextAction.text = template.nextAction;
      final notes = <String>[
        if (template.content.trim().isNotEmpty) template.content.trim(),
        if (template.note.trim().isNotEmpty) template.note.trim(),
      ];
      _note.text = notes.toSet().join('\n');
      _message = null;
    });
  }

  void _toggleItem(FieldReportSettingItem item) {
    setState(() {
      if (!_selectedIds.add(item.id)) {
        _selectedIds.remove(item.id);
      }
      _message = null;
    });
  }

  void _toggleQuickNote(String value) {
    setState(() {
      if (!_selectedQuickNotes.add(value)) {
        _selectedQuickNotes.remove(value);
      }
      _message = null;
    });
  }

  List<FieldReportSettingItem> get _selectedItems {
    return _groups
        .expand((group) => group.items)
        .where((item) => _selectedIds.contains(item.id))
        .toList(growable: false);
  }

  bool _isCompetitor(FieldReportSettingItem item) {
    final value = '${item.groupKey} ${item.groupTitle}'.toLowerCase();
    return value.contains('competitor') ||
        value.contains('đối thủ') ||
        value.contains('doi thu');
  }

  bool _isUsedProduct(FieldReportSettingItem item) {
    final value = '${item.groupKey} ${item.groupTitle}'.toLowerCase();
    return value.contains('used_product') ||
        value.contains('sp đang dùng') ||
        value.contains('san pham dang dung') ||
        value.contains('sản phẩm đang dùng');
  }

  bool _isCompetitorGroup(FieldReportSettingGroup group) {
    final value = '${group.key} ${group.title}'.toLowerCase();
    return value.contains('competitor') ||
        value.contains('đối thủ') ||
        value.contains('doi thu') ||
        group.items.any(_isCompetitor);
  }

  bool _isUsedProductGroup(FieldReportSettingGroup group) {
    final value = '${group.key} ${group.title}'.toLowerCase();
    return value.contains('used_') ||
        value.contains('used_product') ||
        value.contains('sp đang dùng') ||
        value.contains('san pham dang dung') ||
        value.contains('sản phẩm đang dùng') ||
        group.items.any(_isUsedProduct);
  }

  bool _isFieldGroup(FieldReportSettingGroup group) {
    final value = '${group.key} ${group.title}'.toLowerCase();
    return value.contains('report_field') ||
        value.contains('report-field') ||
        value.contains('field báo cáo') ||
        value.contains('field bao cao');
  }

  List<FieldReportSettingItem> get _competitorItems => _groups
      .where(_isCompetitorGroup)
      .expand((group) => group.items)
      .toList(growable: false);

  List<FieldReportSettingGroup> get _usedProductGroups =>
      _groups.where(_isUsedProductGroup).toList(growable: false);

  List<FieldReportSettingGroup> get _extraSettingGroups => _groups
      .where(
        (group) =>
            !_isCompetitorGroup(group) &&
            !_isUsedProductGroup(group) &&
            !_isFieldGroup(group),
      )
      .toList(growable: false);

  Map<String, Object?> _fields() {
    final noteParts = <String>[
      ..._selectedQuickNotes,
      if (_note.text.trim().isNotEmpty) _note.text.trim(),
    ];
    final competitorParts = <String>[
      ..._selectedItems.where(_isCompetitor).map((item) => item.label),
      if (_competitor.text.trim().isNotEmpty) _competitor.text.trim(),
    ];
    return {
      'priceSummary': _price.text.trim(),
      'competitorSummary': competitorParts.toSet().join(', '),
      'displaySummary': _display.text.trim(),
      'stockSummary': _stock.text.trim(),
      'demandSummary': _demand.text.trim(),
      'opportunitySummary': _opportunity.text.trim(),
      'riskSummary': _risk.text.trim(),
      'nextAction': _nextAction.text.trim(),
      'note': noteParts.join(', '),
    };
  }

  String _content(
    Map<String, Object?> fields,
    List<FieldReportSettingItem> selected,
  ) {
    final parts = <String>[];
    if (selected.isNotEmpty) {
      parts.add(
        selected.map((item) => '${item.groupTitle}: ${item.label}').join('\n'),
      );
    }
    const labels = <String, String>{
      'priceSummary': 'Giá / lý do',
      'competitorSummary': 'Đối thủ',
      'displaySummary': 'Trưng bày',
      'stockSummary': 'Tồn kho',
      'demandSummary': 'Nhu cầu',
      'opportunitySummary': 'Cơ hội',
      'riskSummary': 'Rủi ro',
      'nextAction': 'Việc tiếp theo',
      'note': 'Ghi chú',
    };
    for (final entry in labels.entries) {
      final value = (fields[entry.key] ?? '').toString().trim();
      if (value.isNotEmpty) parts.add('${entry.value}: $value');
    }
    return parts.join('\n');
  }

  Map<String, Object?> _payload() {
    final selected = _selectedItems;
    final fields = _fields();
    final all = selected
        .map((item) => item.toSelectionJson())
        .toList(growable: false);
    final competitors = selected
        .where(_isCompetitor)
        .map((item) => item.toSelectionJson())
        .toList(growable: false);
    final usedProducts = selected
        .where(_isUsedProduct)
        .map((item) => item.toSelectionJson())
        .toList(growable: false);

    return {
      'sessionCustomerId': widget.line.sessionCustomerId,
      'reportType': 'market_report',
      'content': _content(fields, selected),
      'fields': fields,
      'selected': {
        'competitors': competitors,
        'usedProducts': usedProducts,
        'settingItems': all,
      },
      'context': {
        'routeId': widget.routeId,
        'routeName': widget.routeName,
        'sessionDate': widget.sessionDate,
        'sales': widget.owner,
        'customerName': widget.line.accountName,
        'area': widget.line.area,
        if ((widget.line.routeCustomerId ?? '').isNotEmpty)
          'routeCustomerId': widget.line.routeCustomerId,
        if (_mediaIds.isNotEmpty) 'mediaIds': _mediaIds,
      },
    };
  }

  bool _hasInput(Map<String, Object?> payload) {
    final value = (payload['content'] ?? '').toString().trim();
    return value.isNotEmpty || _mediaIds.isNotEmpty;
  }

  Future<void> _submit() async {
    if ((widget.line.sessionCustomerId ?? '').isEmpty) {
      setState(() {
        _message = 'Điểm bán không còn thuộc phiên đi tuyến đang mở.';
      });
      return;
    }

    final payload = _payload();
    if (!_hasInput(payload)) {
      setState(() {
        _message = 'Cần nhập ít nhất một nội dung hoặc hình ảnh báo cáo.';
      });
      return;
    }

    final fingerprint = jsonEncode(payload);
    if (_submissionFingerprint != fingerprint || _submissionKey == null) {
      _submissionFingerprint = fingerprint;
      _submissionKey = CanonicalIdempotencyKey.create(
        FieldActivityKind.report.operation,
      );
    }

    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final result = await widget.submissionService.submit(
        kind: FieldActivityKind.report,
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
    final routeCustomerId = (widget.line.routeCustomerId ?? '').trim();
    return Scaffold(
      key: const Key('market-report-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: 'Lập báo cáo',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thông tin cơ bản',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _InfoLine(
                        icon: Icons.storefront_outlined,
                        title: widget.line.accountName,
                        subtitle: [
                          widget.line.area,
                          widget.routeName,
                        ].where((value) => value.trim().isNotEmpty).join(' · '),
                      ),
                      const Divider(height: 22),
                      _InfoLine(
                        icon: Icons.calendar_today_outlined,
                        title: widget.sessionDate,
                        subtitle: 'Ngày báo cáo theo phiên đi tuyến',
                      ),
                    ],
                  ),
                ),
                if (_loadingTemplates) ...[
                  const SizedBox(height: AppSpacing.md),
                  const LinearProgressIndicator(
                    key: Key('market-report-template-loading'),
                    minHeight: 2,
                  ),
                ] else if (_templates.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  const _SectionTitle(
                    title: 'Mẫu báo cáo',
                    subtitle:
                        'Chọn mẫu dùng sẵn rồi điều chỉnh theo tình hình thực tế.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: _templates
                          .map(
                            (template) => ChoiceChip(
                              key: Key(
                                'market-report-template-${template.id}',
                              ),
                              selected:
                                  _selectedTemplateId == template.id,
                              label: Text(template.title),
                              onSelected: _saving
                                  ? null
                                  : (_) => _applyTemplate(template),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                const _SectionTitle(
                  title: 'Nội dung báo cáo',
                  subtitle: 'Ghi nhận ngắn, đúng tình hình tại điểm bán.',
                ),
                const SizedBox(height: AppSpacing.sm),
                const Row(
                  children: [
                    Expanded(
                      child: _ReportTopic(
                        icon: Icons.inventory_2_outlined,
                        label: 'Tình trạng hàng',
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ReportTopic(
                        icon: Icons.groups_2_outlined,
                        label: 'Hoạt động đối thủ',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Row(
                  children: [
                    Expanded(
                      child: _ReportTopic(
                        icon: Icons.sell_outlined,
                        label: 'Giá & nhu cầu',
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ReportTopic(
                        icon: Icons.lightbulb_outline_rounded,
                        label: 'Cơ hội & việc tiếp theo',
                      ),
                    ),
                  ],
                ),
                if (_loadingSettings) ...[
                  const SizedBox(height: AppSpacing.md),
                  const LinearProgressIndicator(minHeight: 2),
                ] else ...[
                  if (_competitorItems.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    const _SectionTitle(
                      title: 'Đối thủ',
                      subtitle: 'Chọn thương hiệu đối thủ đang hiện diện tại điểm bán.',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _SettingItemsCard(
                      key: const Key('market-report-competitors'),
                      items: _competitorItems,
                      selectedIds: _selectedIds,
                      enabled: !_saving,
                      onToggle: _toggleItem,
                    ),
                  ],
                  if (_usedProductGroups.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    const _SectionTitle(
                      title: 'Sản phẩm khách đang dùng',
                      subtitle:
                          'Ghi nhận đúng nhóm sản phẩm khách đang sử dụng.',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ..._usedProductGroups.map(
                      (group) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _SettingItemsCard(
                          key: Key('market-report-used-${group.key}'),
                          title: group.title,
                          description: group.description,
                          items: group.items,
                          selectedIds: _selectedIds,
                          enabled: !_saving,
                          onToggle: _toggleItem,
                        ),
                      ),
                    ),
                  ],
                  if (_extraSettingGroups.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    const _SectionTitle(
                      title: 'Thông tin bổ sung',
                      subtitle: 'Các lựa chọn nghiệp vụ đang được bật.',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ..._extraSettingGroups.map(
                      (group) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _SettingItemsCard(
                          title: group.title,
                          description: group.description,
                          items: group.items,
                          selectedIds: _selectedIds,
                          enabled: !_saving,
                          onToggle: _toggleItem,
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.sm),
                _ReportField(
                  controller: _price,
                  label: 'Giá / lý do',
                  hint: 'Giá đang bán, phản hồi về giá...',
                  enabled: !_saving,
                ),
                _ReportField(
                  controller: _competitor,
                  label: 'Ghi thêm về đối thủ',
                  hint: 'Chương trình, giá hoặc hoạt động cần lưu ý...',
                  enabled: !_saving,
                ),
                _ReportField(
                  controller: _display,
                  label: 'Trưng bày',
                  hint: 'Vị trí, độ phủ, cách trưng bày...',
                  enabled: !_saving,
                ),
                _ReportField(
                  controller: _stock,
                  label: 'Tồn kho',
                  hint: 'Còn nhiều, sắp hết, thiếu mặt hàng...',
                  enabled: !_saving,
                ),
                _ReportField(
                  controller: _demand,
                  label: 'Nhu cầu',
                  hint: 'Nhu cầu hiện tại hoặc sắp tới...',
                  enabled: !_saving,
                ),
                _ReportField(
                  controller: _opportunity,
                  label: 'Cơ hội',
                  hint: 'Cơ hội bán thêm hoặc thay thế sản phẩm...',
                  enabled: !_saving,
                ),
                _ReportField(
                  controller: _risk,
                  label: 'Rủi ro',
                  hint: 'Khó khăn cần Công Ty lưu ý...',
                  enabled: !_saving,
                ),
                _ReportField(
                  controller: _nextAction,
                  label: 'Việc tiếp theo',
                  hint: 'Ví dụ: gửi báo giá, mang mẫu, gọi lại...',
                  enabled: !_saving,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Ghi chú nhanh',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
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
                const SizedBox(height: AppSpacing.sm),
                _ReportField(
                  controller: _note,
                  label: 'Ghi chú khác',
                  hint: 'Thông tin bổ sung cần lưu lại...',
                  enabled: !_saving,
                  minLines: 3,
                ),
                if (routeCustomerId.isNotEmpty &&
                    widget.mediaClient != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  const _SectionTitle(
                    title: 'Hình ảnh',
                    subtitle:
                        'Ảnh điểm bán được lưu cùng hồ sơ và gắn vào báo cáo.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutletPhotoSection(
                    routeCustomerId: routeCustomerId,
                    customerName: widget.line.accountName,
                    sessionId: widget.sessionId,
                    mediaClient: widget.mediaClient!,
                    photoPicker:
                        widget.photoPicker ?? DeviceOutletPhotoPicker(),
                    onProfileChanged: (profile) {
                      if (!mounted) return;
                      setState(() {
                        _mediaIds = profile.media
                            .map((item) => item.id)
                            .toList(growable: false);
                      });
                    },
                  ),
                ],
                if ((_message ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _MessageCard(message: _message!),
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
            key: const Key('market-report-submit'),
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
                : const Icon(Icons.send_rounded),
            label: Text(_saving ? 'Đang gửi...' : 'Gửi báo cáo'),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _ReportTopic extends StatelessWidget {
  const _ReportTopic({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingItemsCard extends StatelessWidget {
  const _SettingItemsCard({
    required this.items,
    required this.selectedIds,
    required this.enabled,
    required this.onToggle,
    super.key,
    this.title,
    this.description,
  });

  final String? title;
  final String? description;
  final List<FieldReportSettingItem> items;
  final Set<String> selectedIds;
  final bool enabled;
  final ValueChanged<FieldReportSettingItem> onToggle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((title ?? '').isNotEmpty) ...[
            Text(
              title!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            if ((description ?? '').isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                description!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
          ],
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: items
                .map(
                  (item) => FilterChip(
                    key: Key('market-report-setting-${item.id}'),
                    selected: selectedIds.contains(item.id),
                    label: Text(item.label),
                    onSelected: enabled ? (_) => onToggle(item) : null,
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _ReportField extends StatelessWidget {
  const _ReportField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.enabled,
    this.minLines = 2,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool enabled;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextField(
        controller: controller,
        enabled: enabled,
        minLines: minLines,
        maxLines: minLines + 2,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

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
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

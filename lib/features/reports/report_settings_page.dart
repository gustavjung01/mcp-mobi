import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_activity_client.dart';
import '../../core/idempotency/canonical_idempotency.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/navy_page_header.dart';

class ReportSettingsPage extends StatefulWidget {
  const ReportSettingsPage({required this.client, super.key});

  final FieldReportSettingsAdminClient client;

  @override
  State<ReportSettingsPage> createState() => _ReportSettingsPageState();
}

class _ReportSettingsPageState extends State<ReportSettingsPage> {
  List<FieldReportSettingGroup> _groups = const [];
  final Map<String, String> _intentKeys = {};
  bool _loading = true;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _keyFor(String operation, Map<String, Object?> payload) {
    final fingerprint = '$operation:${jsonEncode(payload)}';
    return _intentKeys.putIfAbsent(
      fingerprint,
      () => CanonicalIdempotencyKey.create(operation),
    );
  }

  void _completeIntent(String operation, Map<String, Object?> payload) {
    _intentKeys.remove('$operation:${jsonEncode(payload)}');
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _message = null;
      });
    }
    try {
      final groups = await widget.client.loadReportSettingGroups();
      if (!mounted) return;
      setState(() => _groups = groups);
    } on FieldActivityFailure catch (failure) {
      if (!mounted) return;
      setState(() => _message = failure.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editGroup([FieldReportSettingGroup? group]) async {
    if (_saving) return;
    final input = await showModalBottomSheet<_GroupInput>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GroupSheet(group: group),
    );
    if (input == null || !mounted) return;
    await _saveGroup(group, input);
  }

  Future<void> _saveGroup(
    FieldReportSettingGroup? group,
    _GroupInput input,
  ) async {
    final operation = group == null
        ? 'mcp.report-setting-group.create'
        : 'mcp.report-setting-group.update';
    final payload = <String, Object?>{
      if (group != null) 'groupId': group.id,
      'title': input.title,
      'description': input.description,
      'sortOrder': input.sortOrder,
      'status': input.status,
    };
    final key = _keyFor(operation, payload);
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await widget.client.saveReportSettingGroup(
        groupId: group?.id,
        title: input.title,
        description: input.description,
        sortOrder: input.sortOrder,
        status: input.status,
        idempotencyKey: key,
      );
      _completeIntent(operation, payload);
      await _load();
      if (!mounted) return;
      setState(() {
        _message = group == null
            ? 'Đã thêm nhóm lựa chọn báo cáo.'
            : 'Đã cập nhật nhóm lựa chọn báo cáo.';
      });
    } on FieldActivityFailure catch (failure) {
      if (!mounted) return;
      setState(() => _message = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleGroup(FieldReportSettingGroup group) {
    return _saveGroup(
      group,
      _GroupInput(
        title: group.title,
        description: group.description,
        sortOrder: group.sortOrder,
        status: group.status == 'active' ? 'inactive' : 'active',
      ),
    );
  }

  Future<void> _editItem(
    FieldReportSettingGroup group, [
    FieldReportSettingItem? item,
  ]) async {
    if (_saving) return;
    final input = await showModalBottomSheet<_ItemInput>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ItemSheet(group: group, item: item),
    );
    if (input == null || !mounted) return;
    await _saveItem(group, item, input);
  }

  Future<void> _saveItem(
    FieldReportSettingGroup group,
    FieldReportSettingItem? item,
    _ItemInput input,
  ) async {
    final operation = item == null
        ? 'mcp.report-setting-item.create'
        : 'mcp.report-setting-item.update';
    final payload = <String, Object?>{
      if (item != null) 'itemId': item.id,
      'groupId': group.id,
      'label': input.label,
      'value': input.value,
      'category': input.category,
      'brandName': input.brandName,
      'productId': input.productId,
      'sortOrder': input.sortOrder,
      'status': input.status,
    };
    final key = _keyFor(operation, payload);
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await widget.client.saveReportSettingItem(
        itemId: item?.id,
        groupId: group.id,
        label: input.label,
        value: input.value,
        category: input.category,
        brandName: input.brandName,
        productId: input.productId,
        sortOrder: input.sortOrder,
        status: input.status,
        idempotencyKey: key,
      );
      _completeIntent(operation, payload);
      await _load();
      if (!mounted) return;
      setState(() {
        _message = item == null
            ? 'Đã thêm lựa chọn báo cáo.'
            : 'Đã cập nhật lựa chọn báo cáo.';
      });
    } on FieldActivityFailure catch (failure) {
      if (!mounted) return;
      setState(() => _message = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleItem(
    FieldReportSettingGroup group,
    FieldReportSettingItem item,
  ) {
    return _saveItem(
      group,
      item,
      _ItemInput(
        label: item.label,
        value: item.value,
        category: item.category,
        brandName: item.brandName,
        productId: item.productId,
        sortOrder: item.sortOrder,
        status: item.status == 'active' ? 'inactive' : 'active',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('report-settings-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: 'Thiết lập báo cáo thị trường',
            subtitle: 'Nhóm và lựa chọn dùng chung',
            leading: IconButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            trailing: IconButton(
              key: const Key('report-settings-refresh'),
              onPressed: _saving ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
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
                  AppCard(
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Danh mục lựa chọn',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Dùng cho Đối thủ, Sản phẩm khách đang dùng và các lựa chọn báo cáo khác.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        FilledButton.icon(
                          key: const Key('report-setting-add-group'),
                          onPressed: _saving ? null : () => _editGroup(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Thêm nhóm'),
                        ),
                      ],
                    ),
                  ),
                  if ((_message ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      child: Text(
                        _message!,
                        key: const Key('report-settings-message'),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_groups.isEmpty)
                    const AppCard(
                      child: EmptyState(
                        icon: Icons.tune_rounded,
                        title: 'Chưa có nhóm mẫu',
                        message:
                            'Thêm nhóm để chuẩn hóa lựa chọn dùng trong báo cáo thị trường.',
                      ),
                    )
                  else
                    ..._groups.map(
                      (group) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _GroupCard(
                          group: group,
                          busy: _saving,
                          onEdit: () => _editGroup(group),
                          onToggle: () => _toggleGroup(group),
                          onAddItem: () => _editItem(group),
                          onEditItem: (item) => _editItem(group, item),
                          onToggleItem: (item) => _toggleItem(group, item),
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

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.busy,
    required this.onEdit,
    required this.onToggle,
    required this.onAddItem,
    required this.onEditItem,
    required this.onToggleItem,
  });

  final FieldReportSettingGroup group;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onAddItem;
  final ValueChanged<FieldReportSettingItem> onEditItem;
  final ValueChanged<FieldReportSettingItem> onToggleItem;

  @override
  Widget build(BuildContext context) {
    final active = group.status == 'active';
    final items = [...group.items]
      ..sort((left, right) {
        final order = left.sortOrder.compareTo(right.sortOrder);
        if (order != 0) return order;
        return left.label.compareTo(right.label);
      });
    return AppCard(
      key: Key('report-setting-group-${group.id}'),
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
                      group.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (group.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        group.description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${items.length} lựa chọn · Thứ tự ${group.sortOrder}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatePill(active: active),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton(
                key: Key('report-setting-group-edit-${group.id}'),
                onPressed: busy ? null : onEdit,
                child: const Text('Sửa nhóm'),
              ),
              OutlinedButton(
                key: Key('report-setting-group-toggle-${group.id}'),
                onPressed: busy ? null : onToggle,
                child: Text(active ? 'Tắt nhóm' : 'Bật nhóm'),
              ),
              FilledButton.tonalIcon(
                key: Key('report-setting-add-item-${group.id}'),
                onPressed: busy ? null : onAddItem,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Thêm lựa chọn'),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const Divider(height: AppSpacing.lg),
            ...items.map(
              (item) => _ItemRow(
                item: item,
                busy: busy,
                onEdit: () => onEditItem(item),
                onToggle: () => onToggleItem(item),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.busy,
    required this.onEdit,
    required this.onToggle,
  });

  final FieldReportSettingItem item;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final active = item.status == 'active';
    final metadata = [
      item.category,
      item.brandName,
      if (item.productId.isNotEmpty) 'Có liên kết sản phẩm',
      'Thứ tự ${item.sortOrder}',
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    return Padding(
      key: Key('report-setting-item-${item.id}'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (metadata.isNotEmpty)
                  Text(
                    metadata,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            key: Key('report-setting-item-edit-${item.id}'),
            tooltip: 'Sửa lựa chọn',
            onPressed: busy ? null : onEdit,
            icon: const Icon(Icons.edit_outlined, size: 19),
          ),
          TextButton(
            key: Key('report-setting-item-toggle-${item.id}'),
            onPressed: busy ? null : onToggle,
            child: Text(active ? 'Tắt' : 'Bật'),
          ),
        ],
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active ? AppColors.successSoft : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'Đang bật' : 'Đã tắt',
        style: TextStyle(
          color: active ? AppColors.success : AppColors.textSecondary,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _GroupInput {
  const _GroupInput({
    required this.title,
    required this.description,
    required this.sortOrder,
    required this.status,
  });
  final String title;
  final String description;
  final int sortOrder;
  final String status;
}

class _GroupSheet extends StatefulWidget {
  const _GroupSheet({this.group});
  final FieldReportSettingGroup? group;

  @override
  State<_GroupSheet> createState() => _GroupSheetState();
}

class _GroupSheetState extends State<_GroupSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _sortOrder;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.group?.title ?? '');
    _description = TextEditingController(text: widget.group?.description ?? '');
    _sortOrder = TextEditingController(
      text: (widget.group?.sortOrder ?? 0).toString(),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.group != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              editing ? 'Sửa nhóm lựa chọn' : 'Thêm nhóm lựa chọn',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('report-setting-group-title'),
              controller: _title,
              decoration: const InputDecoration(labelText: 'Tên nhóm'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('report-setting-group-description'),
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('report-setting-group-sort'),
              controller: _sortOrder,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Thứ tự hiển thị'),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('report-setting-group-save'),
                onPressed: () {
                  final title = _title.text.trim();
                  final order = int.tryParse(_sortOrder.text.trim());
                  if (title.isEmpty || order == null || order < 0) return;
                  Navigator.of(context).pop(
                    _GroupInput(
                      title: title,
                      description: _description.text.trim(),
                      sortOrder: order,
                      status: widget.group?.status ?? 'active',
                    ),
                  );
                },
                child: Text(editing ? 'Lưu thay đổi' : 'Thêm nhóm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemInput {
  const _ItemInput({
    required this.label,
    required this.value,
    required this.category,
    required this.brandName,
    required this.productId,
    required this.sortOrder,
    required this.status,
  });
  final String label;
  final String value;
  final String category;
  final String brandName;
  final String productId;
  final int sortOrder;
  final String status;
}

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({required this.group, this.item});
  final FieldReportSettingGroup group;
  final FieldReportSettingItem? item;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final TextEditingController _label;
  late final TextEditingController _value;
  late final TextEditingController _category;
  late final TextEditingController _brand;
  late final TextEditingController _sortOrder;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.item?.label ?? '');
    _value = TextEditingController(text: widget.item?.value ?? '');
    _category = TextEditingController(text: widget.item?.category ?? '');
    _brand = TextEditingController(text: widget.item?.brandName ?? '');
    _sortOrder = TextEditingController(
      text: (widget.item?.sortOrder ?? 0).toString(),
    );
  }

  @override
  void dispose() {
    _label.dispose();
    _value.dispose();
    _category.dispose();
    _brand.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              editing ? 'Sửa lựa chọn' : 'Thêm lựa chọn',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              widget.group.title,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('report-setting-item-label'),
              controller: _label,
              decoration: const InputDecoration(labelText: 'Tên lựa chọn'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('report-setting-item-value'),
              controller: _value,
              decoration: const InputDecoration(
                labelText: 'Giá trị lưu',
                hintText: 'Để trống sẽ dùng tên lựa chọn',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('report-setting-item-category'),
              controller: _category,
              decoration: const InputDecoration(labelText: 'Nhóm sản phẩm'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('report-setting-item-brand'),
              controller: _brand,
              decoration: const InputDecoration(labelText: 'Nhãn hàng'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('report-setting-item-sort'),
              controller: _sortOrder,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Thứ tự hiển thị'),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('report-setting-item-save'),
                onPressed: () {
                  final label = _label.text.trim();
                  final order = int.tryParse(_sortOrder.text.trim());
                  if (label.isEmpty || order == null || order < 0) return;
                  Navigator.of(context).pop(
                    _ItemInput(
                      label: label,
                      value:
                          _value.text.trim().isEmpty ? label : _value.text.trim(),
                      category: _category.text.trim(),
                      brandName: _brand.text.trim(),
                      productId: widget.item?.productId ?? '',
                      sortOrder: order,
                      status: widget.item?.status ?? 'active',
                    ),
                  );
                },
                child: Text(editing ? 'Lưu thay đổi' : 'Thêm lựa chọn'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

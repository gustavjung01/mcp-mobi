import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/navy_page_header.dart';

class OutletEditInput {
  const OutletEditInput({
    required this.name,
    required this.phone,
    required this.area,
    required this.address,
    required this.sortOrder,
    required this.note,
  });

  final String name;
  final String phone;
  final String area;
  final String address;
  final int sortOrder;
  final String note;
}

class OutletEditPage extends StatefulWidget {
  const OutletEditPage({
    required this.name,
    required this.phone,
    required this.area,
    required this.address,
    required this.sortOrder,
    required this.note,
    super.key,
  });

  final String name;
  final String phone;
  final String area;
  final String address;
  final int sortOrder;
  final String note;

  @override
  State<OutletEditPage> createState() => _OutletEditPageState();
}

class _OutletEditPageState extends State<OutletEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _area;
  late final TextEditingController _address;
  late final TextEditingController _sortOrder;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
    _phone = TextEditingController(text: widget.phone);
    _area = TextEditingController(text: widget.area);
    _address = TextEditingController(text: widget.address);
    _sortOrder = TextEditingController(
      text: widget.sortOrder > 0 ? widget.sortOrder.toString() : '',
    );
    _note = TextEditingController(text: widget.note);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _area.dispose();
    _address.dispose();
    _sortOrder.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final sortOrder = int.tryParse(_sortOrder.text.trim()) ?? 0;
    if (name.isEmpty || sortOrder < 0) return;
    Navigator.of(context).pop(
      OutletEditInput(
        name: name,
        phone: _phone.text.trim(),
        area: _area.text.trim(),
        address: _address.text.trim(),
        sortOrder: sortOrder,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('outlet-edit-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: 'Chỉnh sửa điểm bán',
            subtitle: 'Cập nhật thông tin dùng chung cho tuyến và phiên đang mở',
            leading: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                TextField(
                  key: const Key('outlet-edit-name'),
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Tên điểm bán *'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Điện thoại'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _area,
                  decoration: const InputDecoration(labelText: 'Khu vực'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _address,
                  decoration: const InputDecoration(labelText: 'Địa chỉ'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _sortOrder,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Thứ tự ghé'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _note,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Ghi chú'),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  key: const Key('outlet-edit-save'),
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Lưu thay đổi'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

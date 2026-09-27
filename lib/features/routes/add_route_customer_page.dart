import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_data_client.dart';
import '../../core/idempotency/canonical_idempotency.dart';
import '../../core/location/field_location.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/navy_page_header.dart';

class AddRouteCustomerPage extends StatefulWidget {
  const AddRouteCustomerPage({
    super.key,
    required this.routeName,
    required this.sessionId,
    required this.actionClient,
    required this.locationProvider,
  });

  final String routeName;
  final String sessionId;
  final FieldActionClient actionClient;
  final FieldLocationProvider locationProvider;

  @override
  State<AddRouteCustomerPage> createState() => _AddRouteCustomerPageState();
}

class _AddRouteCustomerPageState extends State<AddRouteCustomerPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _areaController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();

  FieldLocation? _location;
  String? _idempotencyKey;
  String? _message;
  bool _locating = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _markIntentChanged() {
    _idempotencyKey = null;
    if (_message != null) {
      setState(() {
        _message = null;
      });
    }
  }

  Future<void> _captureLocation() async {
    if (_locating || _saving) return;
    setState(() {
      _locating = true;
      _message = null;
    });
    try {
      final location = await widget.locationProvider.current();
      if (!mounted) return;
      setState(() {
        _location = location;
        _idempotencyKey = null;
      });
    } on FieldLocationFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _message = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _locating = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    final customerName = _nameController.text.trim();
    if (customerName.isEmpty) {
      setState(() {
        _message = 'Cần nhập tên điểm bán.';
      });
      return;
    }

    final idempotencyKey =
        _idempotencyKey ??= CanonicalIdempotencyKey.create(
          'session-customer.add',
        );
    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      await widget.actionClient.addSessionCustomer(
        sessionId: widget.sessionId,
        customerName: customerName,
        phone: _phoneController.text,
        area: _areaController.text,
        address: _addressController.text,
        note: _noteController.text,
        latitude: _location?.latitude,
        longitude: _location?.longitude,
        accuracy: _location?.accuracy,
        idempotencyKey: idempotencyKey,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FieldDataFailure catch (failure) {
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
    final location = _location;
    return Scaffold(
      key: const Key('route-add-customer-screen'),
      body: SafeArea(
        child: Column(
          children: [
            NavyPageHeader(
              title: 'Thêm khách',
              subtitle: widget.routeName,
              leading: IconButton(
                tooltip: 'Quay lại',
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
                  AppSpacing.xl,
                ),
                children: [
                  const Text(
                    'Thông tin điểm bán',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Điểm bán sẽ được thêm vào tuyến và phiên đang thực hiện.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    child: Column(
                      children: [
                        TextField(
                          key: const Key('route-add-customer-name'),
                          controller: _nameController,
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _markIntentChanged(),
                          decoration: const InputDecoration(
                            labelText: 'Tên điểm bán *',
                            hintText: 'Tên cửa hàng / điểm bán',
                            prefixIcon: Icon(Icons.storefront_outlined),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          key: const Key('route-add-customer-phone'),
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _markIntentChanged(),
                          decoration: const InputDecoration(
                            labelText: 'Điện thoại',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          key: const Key('route-add-customer-area'),
                          controller: _areaController,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _markIntentChanged(),
                          decoration: const InputDecoration(
                            labelText: 'Khu vực',
                            hintText: 'Ấp / xã / huyện',
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          key: const Key('route-add-customer-address'),
                          controller: _addressController,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _markIntentChanged(),
                          decoration: const InputDecoration(
                            labelText: 'Địa chỉ',
                            prefixIcon: Icon(Icons.place_outlined),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          key: const Key('route-add-customer-note'),
                          controller: _noteController,
                          minLines: 2,
                          maxLines: 4,
                          onChanged: (_) => _markIntentChanged(),
                          decoration: const InputDecoration(
                            labelText: 'Ghi chú',
                            hintText: 'Thông tin cần nhớ',
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: location == null
                                ? AppColors.primarySoft
                                : AppColors.successSoft,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            location == null
                                ? Icons.my_location_outlined
                                : Icons.location_on_rounded,
                            color: location == null
                                ? AppColors.primary
                                : AppColors.success,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Vị trí điểm bán',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                location == null
                                    ? 'Có thể lấy GPS khi đang đứng tại điểm bán.'
                                    : 'Đã lấy GPS · sai số khoảng ${location.accuracy.round()} m',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              OutlinedButton.icon(
                                key: const Key(
                                  'route-add-customer-location',
                                ),
                                onPressed:
                                    _locating || _saving ? null : _captureLocation,
                                icon: _locating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.gps_fixed_rounded,
                                        size: 18,
                                      ),
                                label: Text(
                                  _locating
                                      ? 'Đang lấy vị trí...'
                                      : location == null
                                      ? 'Lấy vị trí hiện tại'
                                      : 'Lấy lại vị trí',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if ((_message ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.danger,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _message!,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('route-add-customer-submit'),
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
                          : const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(
                        _saving ? 'Đang thêm...' : 'Thêm vào tuyến hôm nay',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

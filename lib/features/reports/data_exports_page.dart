import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/field_data_client.dart';
import '../../core/data/field_history_client.dart';
import '../../core/data/order_data_client.dart';
import '../../core/export/mobile_document_share.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/navy_page_header.dart';

class DataExportsPage extends StatefulWidget {
  const DataExportsPage({
    super.key,
    this.historyClient,
    this.fieldDataClient,
    this.orderDataClient,
    this.sharePort = const DeviceDocumentShare(),
  });

  final FieldHistoryClient? historyClient;
  final FieldDataClient? fieldDataClient;
  final OrderDataClient? orderDataClient;
  final DocumentSharePort sharePort;

  @override
  State<DataExportsPage> createState() => _DataExportsPageState();
}

class _DataExportsPageState extends State<DataExportsPage> {
  String? _busy;
  String? _message;

  Future<void> _share(
    String key,
    String fileName,
    Future<Iterable<Iterable<Object?>>> Function() loadRows,
  ) async {
    if (_busy != null) return;
    setState(() {
      _busy = key;
      _message = null;
    });
    try {
      final rows = await loadRows();
      final file = SessionReportExporter.buildCsv(
        fileName: fileName,
        rows: rows,
      );
      await widget.sharePort.shareTextDocument(
        fileName: file.fileName,
        mimeType: file.mimeType,
        content: file.content,
      );
    } on FieldHistoryFailure catch (failure) {
      if (mounted) setState(() => _message = failure.message);
    } on FieldDataFailure catch (failure) {
      if (mounted) setState(() => _message = failure.message);
    } on OrderDataFailure catch (failure) {
      if (mounted) setState(() => _message = failure.message);
    } on DocumentShareFailure catch (failure) {
      if (mounted) setState(() => _message = failure.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Không xuất được dữ liệu. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<Iterable<Iterable<Object?>>> _sessionRows() async {
    final rows = await widget.historyClient!.loadSessionHistory();
    return [
      ['Mã phiên', 'Tuyến', 'Ngày', 'Nhân viên', 'Trạng thái', 'Kế hoạch', 'Đã ghé', 'Đơn hàng', 'Thử sản phẩm', 'Báo cáo', 'Công việc'],
      ...rows.map((x) => [
        x.id, x.routeName, x.sessionDate ?? '', x.salesOwner, x.status,
        x.planned, x.visited, x.orders, x.tests, x.reports, x.followups,
      ]),
    ];
  }

  Future<Iterable<Iterable<Object?>>> _outletRows() async {
    final rows = await widget.fieldDataClient!.loadOutlets();
    return [
      ['Mã điểm bán', 'Mã khách Công Ty', 'Tên điểm bán', 'Tuyến', 'Khu vực', 'Địa chỉ', 'Điện thoại', 'Trạng thái', 'Ghi chú'],
      ...rows.map((x) => [
        x.id, x.coreCustomerCode ?? x.code, x.name, x.routeName, x.area,
        x.address, x.phone, x.status, x.note,
      ]),
    ];
  }

  Future<Iterable<Iterable<Object?>>> _orderRows() async {
    final rows = await widget.orderDataClient!.loadOrders();
    return [
      ['Mã đơn', 'Số đơn', 'Khách hàng', 'Mã khách', 'Trạng thái', 'Ngày tạo', 'Tổng tiền', 'Phiên bản', 'Ghi chú'],
      ...rows.map((x) => [
        x.id, x.number ?? '', x.customerName ?? '', x.customerCode ?? '',
        x.status, x.createdAt ?? '', x.total ?? 0,
        x.currentVersionNumber ?? '', x.note ?? '',
      ]),
    ];
  }

  Future<List<SessionReportDetail>> _reportDetails() async {
    final client = widget.historyClient!;
    final summaries = await client.loadSessionReports();
    return Future.wait(
      summaries.map((x) => client.loadSessionReportDetail(x.sessionId)),
    );
  }

  Future<Iterable<Iterable<Object?>>> _reportRows() async {
    final details = await _reportDetails();
    return [
      ['Mã phiên', 'Tuyến', 'Ngày', 'Điểm bán', 'Nội dung', 'Đối thủ', 'Cơ hội', 'Rủi ro', 'Việc tiếp theo'],
      for (final detail in details)
        for (final x in detail.marketReports)
          [
            detail.session.sessionId,
            detail.session.routeName,
            detail.session.sessionDate ?? '',
            x.customerName,
            x.content ?? '',
            x.competitorSummary ?? '',
            x.opportunitySummary ?? '',
            x.riskSummary ?? '',
            x.nextAction ?? '',
          ],
    ];
  }

  Future<Iterable<Iterable<Object?>>> _testRows() async {
    final rows = await widget.historyClient!.loadFieldChecks();
    return [
      ['Ngày', 'Tuyến', 'Điểm bán', 'Sản phẩm', 'Kết quả', 'Ghi chú'],
      ...rows.map((x) => [
        x.date ?? '', x.routeName ?? '', x.accountName,
        x.productName, x.status, x.note ?? '',
      ]),
    ];
  }

  Future<Iterable<Iterable<Object?>>> _followupRows() async {
    final rows = await widget.historyClient!.loadTasks();
    return [
      ['Công việc', 'Điểm bán', 'Tuyến', 'Phiên', 'Ngày phiên', 'Ngày hẹn', 'Ưu tiên', 'Phụ trách', 'Trạng thái', 'Nguồn', 'Loại công việc', 'Ghi chú'],
      ...rows.map((x) => [
        x.title, x.customerName, x.routeName, x.sessionId ?? '',
        x.sessionDate ?? '', x.dueDate ?? '', x.priority, x.owner,
        x.status, x.sourceLabel, x.followupType, x.note ?? '',
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final entries = <_ExportEntry>[
      if (widget.historyClient != null)
        _ExportEntry(
          keyName: 'sessions',
          icon: Icons.history_rounded,
          title: 'Phiên đi tuyến',
          subtitle: 'Lịch sử phiên và các chỉ số chính',
          fileName: 'mcp-phien.csv',
          loadRows: _sessionRows,
        ),
      if (widget.orderDataClient != null)
        _ExportEntry(
          keyName: 'orders',
          icon: Icons.receipt_long_outlined,
          title: 'Đơn hàng',
          subtitle: 'Đơn đã tạo từ MCP và trạng thái hiện tại',
          fileName: 'mcp-don-hang.csv',
          loadRows: _orderRows,
        ),
      if (widget.fieldDataClient != null)
        _ExportEntry(
          keyName: 'outlets',
          icon: Icons.storefront_outlined,
          title: 'Điểm bán',
          subtitle: 'Danh bạ điểm bán trong phạm vi MCP',
          fileName: 'mcp-diem-ban.csv',
          loadRows: _outletRows,
        ),
      if (widget.historyClient != null)
        _ExportEntry(
          keyName: 'reports',
          icon: Icons.assignment_outlined,
          title: 'Báo cáo thị trường',
          subtitle: 'Nội dung báo cáo theo các phiên gần đây',
          fileName: 'mcp-bao-cao-thi-truong.csv',
          loadRows: _reportRows,
        ),
      if (widget.historyClient != null)
        _ExportEntry(
          keyName: 'tests',
          icon: Icons.science_outlined,
          title: 'Thử sản phẩm',
          subtitle: 'Kết quả thử và hậu kiểm sản phẩm',
          fileName: 'mcp-thu-san-pham.csv',
          loadRows: _testRows,
        ),
      if (widget.historyClient != null)
        _ExportEntry(
          keyName: 'followups',
          icon: Icons.task_alt_outlined,
          title: 'Kế hoạch & Công việc',
          subtitle: 'Hạn xử lý, phụ trách, nguồn và trạng thái',
          fileName: 'mcp-cong-viec.csv',
          loadRows: _followupRows,
        ),
    ];

    return Scaffold(
      key: const Key('data-exports-screen'),
      body: Column(
        children: [
          NavyPageHeader(
            title: 'Xuất dữ liệu',
            subtitle: 'Các file CSV dùng cho văn phòng',
            leading: IconButton(
              onPressed: _busy == null ? () => Navigator.of(context).pop() : null,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                const AppCard(
                  child: Text(
                    'Chọn nội dung cần xuất. File được tạo từ dữ liệu MCP theo quyền của tài khoản và mở bằng chức năng chia sẻ của thiết bị.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
                if ((_message ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    child: Text(
                      _message!,
                      key: const Key('data-exports-message'),
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                ...entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          key: Key('data-export-${entry.keyName}'),
                        leading: Icon(entry.icon, color: AppColors.primaryDark),
                        title: Text(
                          entry.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(entry.subtitle),
                        trailing: _busy == entry.keyName
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.ios_share_outlined),
                          onTap: _busy == null
                              ? () => _share(
                                    entry.keyName,
                                    entry.fileName,
                                    entry.loadRows,
                                  )
                              : null,
                        ),
                      ),
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

class _ExportEntry {
  const _ExportEntry({
    required this.keyName,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.fileName,
    required this.loadRows,
  });

  final String keyName;
  final IconData icon;
  final String title;
  final String subtitle;
  final String fileName;
  final Future<Iterable<Iterable<Object?>>> Function() loadRows;
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/app/navigation/app_shell.dart';
import 'package:mcp_field/core/auth/mobile_auth_client.dart';
import 'package:mcp_field/core/data/order_data_client.dart';
import 'package:mcp_field/core/idempotency/canonical_idempotency.dart';
import 'package:mcp_field/core/media/outlet_media_client.dart';
import 'package:mcp_field/core/media/outlet_photo_pending_store.dart';
import 'package:mcp_field/core/media/outlet_photo_picker.dart';
import 'package:mcp_field/core/sync/order_offline_store.dart';

const testSession = MobileSession(
  token: 'nppusr.test-token',
  employeeId: 'employee-1',
  loginName: 'staff.test',
  displayName: 'Nhân viên A',
  expiresAt: null,
);

class MemoryOrderOfflineStore implements OrderOfflineStore {
  final Map<String, OrderDraft> drafts = {};
  final Map<String, QueuedOrderMutation> mutations = {};

  @override
  Future<void> deleteDraft(String outletId) async {
    drafts.remove(outletId);
  }

  @override
  Future<List<QueuedOrderMutation>> loadMutations() async {
    return mutations.values.toList(growable: false);
  }

  @override
  Future<OrderDraft?> readDraft(String outletId) async => drafts[outletId];

  @override
  Future<void> removeMutation(String idempotencyKey) async {
    mutations.remove(idempotencyKey);
  }

  @override
  Future<void> saveDraft(OrderDraft draft) async {
    drafts[draft.outletId] = draft;
  }

  @override
  Future<void> saveMutation(QueuedOrderMutation mutation) async {
    mutations[mutation.idempotencyKey] = mutation;
  }
}

class RecordingOrderClient implements OrderDataClient {
  final keys = <String>[];

  @override
  Future<FieldOrder> createOrder({
    required String customerId,
    required String customerAddressId,
    required List<OrderLineInput> lines,
    required String idempotencyKey,
    String? note,
  }) async {
    keys.add(idempotencyKey);
    return const FieldOrder(
      id: 'order-1',
      number: 'SO-001',
      status: 'draft',
    );
  }

  @override
  Future<List<FieldOrder>> loadOrders() async => const [];

  @override
  Future<List<OrderCatalogItem>> searchProducts({
    required String query,
    String? category,
    String? brand,
  }) async => const [];
}

class MemoryPhotoPendingStore implements OutletPhotoPendingStore {
  final Map<String, PendingOutletPhoto> items = {};

  @override
  Future<List<PendingOutletPhoto>> load({String? routeCustomerId}) async {
    final requested = (routeCustomerId ?? '').trim();
    return items.values
        .where(
          (item) =>
              requested.isEmpty || item.routeCustomerId == requested,
        )
        .toList(growable: false);
  }

  @override
  Future<void> remove(String clientUploadId) async {
    items.remove(clientUploadId);
  }

  @override
  Future<void> save(PendingOutletPhoto item) async {
    items[item.draft.clientUploadId] = item;
  }
}

class RecordingMediaClient implements OutletMediaClient {
  final uploadIds = <String>[];

  @override
  Future<OutletMediaProfile> loadProfile({
    required String routeCustomerId,
  }) async {
    return const OutletMediaProfile(media: [], mediaLimit: 3);
  }

  @override
  Future<void> uploadPhoto({
    required String routeCustomerId,
    String? sessionId,
    required String clientUploadId,
    required Uint8List bytes,
    required String mimeType,
    required int width,
    required int height,
  }) async {
    expect(routeCustomerId, 'rc-1');
    expect(sessionId, 'session-1');
    uploadIds.add(clientUploadId);
  }

  @override
  Future<void> deleteMedia({required String mediaId}) async {}
}

void main() {
  testWidgets('app restart automatically replays queued order with same key', (
    tester,
  ) async {
    final store = MemoryOrderOfflineStore();
    final client = RecordingOrderClient();
    final key = CanonicalIdempotencyKey.create(
      'mcp.sales-order.create',
      uuid: '123e4567-e89b-42d3-a456-426614174000',
    );
    store.mutations[key] = QueuedOrderMutation(
      idempotencyKey: key,
      outletId: 'outlet-1',
      outletName: 'Điểm bán A',
      customerId: 'customer-1',
      customerAddressId: 'address-1',
      note: '',
      lines: const [
        OrderLineInput(variantId: 'variant-1', quantity: 1),
      ],
      createdAt: DateTime.utc(2026, 9, 28),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          session: testSession,
          orderDataClient: client,
          orderOfflineStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(client.keys, [key]);
    expect(store.mutations[key]!.state, OrderQueueState.acknowledged);
    expect(store.mutations[key]!.serverOrderId, 'order-1');
  });

  testWidgets(
    'app restart automatically replays pending outlet photo with same upload id',
    (tester) async {
      final pending = MemoryPhotoPendingStore();
      final media = RecordingMediaClient();
      const uploadId = 'photo-upload-1';
      pending.items[uploadId] = PendingOutletPhoto(
        routeCustomerId: 'rc-1',
        customerName: 'Điểm bán A',
        sessionId: 'session-1',
        draft: OutletPhotoDraft(
          clientUploadId: uploadId,
          bytes: Uint8List.fromList([1, 2, 3]),
          width: 10,
          height: 10,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            session: testSession,
            outletMediaClient: media,
            outletPhotoPendingStore: pending,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(media.uploadIds, [uploadId]);
      expect(pending.items, isEmpty);
    },
  );
}

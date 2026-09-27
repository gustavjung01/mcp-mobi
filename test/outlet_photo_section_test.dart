import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:mcp_field/core/media/outlet_media_client.dart';
import 'package:mcp_field/core/data/field_data_client.dart';
import 'package:mcp_field/core/media/outlet_photo_picker.dart';
import 'package:mcp_field/features/outlets/outlet_detail_page.dart';
import 'package:mcp_field/features/outlets/outlet_photo_section.dart';

class FakeOutletMediaClient implements OutletMediaClient {
  bool failFirstUpload = true;
  final uploadIds = <String>[];

  @override
  Future<OutletMediaProfile> loadProfile({
    required String routeCustomerId,
  }) async {
    return const OutletMediaProfile(
      media: [],
      mediaLimit: 3,
    );
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
    if (failFirstUpload && uploadIds.length == 1) {
      throw const OutletMediaFailure(
        code: 'MEDIA_UPLOAD_NETWORK',
        message: 'Mạng bị gián đoạn khi gửi ảnh. Vui lòng thử lại.',
        retryable: true,
      );
    }
  }

  @override
  Future<void> deleteMedia({
    required String mediaId,
  }) async {}
}

class FakeOutletPhotoPicker implements OutletPhotoPicker {
  @override
  Future<OutletPhotoDraft?> pickCamera() async {
    final image = image_lib.Image(width: 10, height: 10);
    return OutletPhotoDraft(
      clientUploadId: 'same-upload-id',
      bytes: Uint8List.fromList(image_lib.encodeJpg(image)),
      width: 10,
      height: 10,
    );
  }

  @override
  Future<List<OutletPhotoDraft>> pickGallery({
    required int maxCount,
  }) async {
    return const [];
  }
}

void main() {
  testWidgets('selected outlet photo stays above the blue hero decoration', (
    WidgetTester tester,
  ) async {
    final media = FakeOutletMediaClient()..failFirstUpload = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OutletDetailPage(
          routeName: 'Tuyến Quận 1',
          outlet: const FieldOutlet(
            id: 'rc-1',
            routeId: 'route-1',
            routeName: 'Tuyến Quận 1',
            code: 'MCP001',
            name: 'Cửa hàng Minh Phát',
            phone: '0909000111',
            area: 'Quận 1',
            address: '123 Nguyễn Văn Cừ',
            status: 'linked_existing',
            note: '',
          ),
          mediaClient: media,
          photoPicker: FakeOutletPhotoPicker(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('outlet-hero-blue-overlay')), findsOneWidget);
    expect(find.byKey(const Key('outlet-hero-photo-preview')), findsNothing);

    final camera = find.byKey(const Key('outlet-photo-camera'));
    await tester.ensureVisible(camera);
    await tester.tap(camera);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('outlet-hero-photo-preview')), findsOneWidget);
    expect(find.byKey(const Key('outlet-hero-blue-overlay')), findsNothing);
  });

  testWidgets('failed outlet photo retry keeps the same upload identity', (
    WidgetTester tester,
  ) async {
    final media = FakeOutletMediaClient();
    Uint8List? heroPreview;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OutletPhotoSection(
                routeCustomerId: 'rc-1',
                customerName: 'Cửa hàng Minh Phát',
                sessionId: 'session-1',
                mediaClient: media,
                photoPicker: FakeOutletPhotoPicker(),
                onDraftPreviewChanged: (bytes) {
                  heroPreview = bytes;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('outlet-photo-camera')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('outlet-photo-drafts')), findsOneWidget);
    expect(heroPreview, isNotNull);
    expect(heroPreview, isNotEmpty);

    await tester.tap(find.byKey(const Key('outlet-photo-save')));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại 1 ảnh'), findsOneWidget);

    await tester.tap(find.byKey(const Key('outlet-photo-save')));
    await tester.pumpAndSettle();

    expect(media.uploadIds, ['same-upload-id', 'same-upload-id']);
    expect(find.byKey(const Key('outlet-photo-drafts')), findsNothing);
    expect(heroPreview, isNull);
  });
}

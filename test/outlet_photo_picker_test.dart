import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:mcp_field/core/media/outlet_media_client.dart';
import 'package:mcp_field/core/media/outlet_photo_picker.dart';

void main() {
  test('mobile photo processing mirrors shared MCP media policy', () async {
    final source = image_lib.Image(width: 2000, height: 1000);
    final png = Uint8List.fromList(image_lib.encodePng(source));

    final draft = await prepareOutletPhotoDraft(
      sourceBytes: png,
      clientUploadId: 'upload-1',
    );

    expect(draft.clientUploadId, 'upload-1');
    expect(draft.mimeType, 'image/jpeg');
    expect(draft.width, 1600);
    expect(draft.height, 800);
    expect(draft.bytes.length, lessThanOrEqualTo(outletMediaMaxBytes));
    expect(outletMediaMaxImageEdge, 1600);
    expect(outletMediaJpegQuality, 82);
  });
}

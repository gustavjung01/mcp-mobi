import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/errors/mobile_error_mapper.dart';

void main() {
  test('canonical mapper turns generic 404 409 and 503 into office messages', () {
    expect(
      CanonicalApiErrorMapper.message(
        code: 'NOT_FOUND',
        statusCode: 404,
        serverMessage: 'not found',
        fallbackMessage: 'fallback',
      ),
      contains('không còn sẵn sàng'),
    );
    expect(
      CanonicalApiErrorMapper.message(
        code: 'CONFLICT',
        statusCode: 409,
        serverMessage: 'Dữ liệu đang xung đột với trạng thái hiện tại.',
        fallbackMessage: 'fallback',
      ),
      contains('đã thay đổi'),
    );
    expect(
      CanonicalApiErrorMapper.message(
        code: 'INTERNAL_ERROR',
        statusCode: 503,
        serverMessage: 'internal error',
        fallbackMessage: 'fallback',
      ),
      contains('tạm thời chưa sẵn sàng'),
    );
  });

  test('retryability follows backend hint and transport status', () {
    expect(
      CanonicalApiErrorMapper.isRetryable(
        code: 'REQUEST_FAILED',
        statusCode: 422,
        backendRetryable: false,
      ),
      isFalse,
    );
    expect(
      CanonicalApiErrorMapper.isRetryable(
        code: 'REQUEST_FAILED',
        statusCode: 503,
        backendRetryable: false,
      ),
      isTrue,
    );
    expect(
      CanonicalApiErrorMapper.isRetryable(
        code: 'CUSTOM_RETRY',
        statusCode: 409,
        backendRetryable: true,
      ),
      isTrue,
    );
  });
}

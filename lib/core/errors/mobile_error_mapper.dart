class CanonicalApiErrorMapper {
  const CanonicalApiErrorMapper._();

  static String message({
    required String code,
    required int statusCode,
    required String serverMessage,
    required String fallbackMessage,
    String forbiddenMessage =
        'Tài khoản chưa được cấp quyền thực hiện thao tác này.',
    String notFoundMessage =
        'Dữ liệu không còn sẵn sàng. Cập nhật lại rồi thử lại.',
    String conflictMessage =
        'Dữ liệu đã thay đổi. Cập nhật lại rồi tiếp tục.',
    String validationMessage =
        'Thông tin chưa hợp lệ. Kiểm tra lại trước khi tiếp tục.',
    String unavailableMessage =
        'Hệ thống đang tạm thời chưa sẵn sàng. Vui lòng thử lại.',
  }) {
    final normalizedCode = code.trim().toUpperCase();
    final message = serverMessage.trim();

    if (statusCode == 401) {
      return 'Phiên đăng nhập không còn hiệu lực.';
    }
    if (statusCode == 403) return forbiddenMessage;
    if (statusCode == 404) return notFoundMessage;
    if (statusCode == 409) return conflictMessage;
    if (statusCode == 422) return validationMessage;
    if (statusCode == 429) {
      return 'Hệ thống đang nhận nhiều yêu cầu. Vui lòng thử lại sau ít phút.';
    }
    if (statusCode >= 500 ||
        normalizedCode == 'INTERNAL_ERROR' ||
        normalizedCode == 'SERVICE_UNAVAILABLE') {
      return unavailableMessage;
    }
    if (_isUsableServerMessage(message)) return message;
    return fallbackMessage;
  }

  static bool isRetryable({
    required String code,
    required int statusCode,
    required bool backendRetryable,
  }) {
    final normalizedCode = code.trim().toUpperCase();
    return backendRetryable ||
        normalizedCode == 'NETWORK_TIMEOUT' ||
        normalizedCode == 'NETWORK_UNAVAILABLE' ||
        statusCode == 408 ||
        statusCode == 425 ||
        statusCode == 429 ||
        statusCode >= 500;
  }

  static bool _isUsableServerMessage(String message) {
    if (message.isEmpty) return false;
    final normalized = message.toLowerCase();
    return !normalized.contains('xung đột với trạng thái hiện tại') &&
        !normalized.contains('conflict with current state') &&
        !normalized.contains('đã xảy ra lỗi nội bộ') &&
        !normalized.contains('internal error') &&
        normalized != 'request failed' &&
        normalized != 'not found';
  }
}

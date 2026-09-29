enum AppSyncPhase {
  synced,
  syncing,
  waiting,
  error,
}

class AppSyncStatus {
  const AppSyncStatus._({
    required this.phase,
    required this.message,
  });

  const AppSyncStatus.synced()
    : this._(
        phase: AppSyncPhase.synced,
        message: 'Dữ liệu trên thiết bị đã đồng bộ.',
      );

  const AppSyncStatus.syncing()
    : this._(
        phase: AppSyncPhase.syncing,
        message: 'Đang gửi dữ liệu chờ lên hệ thống.',
      );

  factory AppSyncStatus.waiting(int count) {
    return AppSyncStatus._(
      phase: AppSyncPhase.waiting,
      message: 'Còn $count thao tác đang chờ gửi.',
    );
  }

  factory AppSyncStatus.error(String message) {
    return AppSyncStatus._(
      phase: AppSyncPhase.error,
      message: message,
    );
  }

  final AppSyncPhase phase;
  final String message;

  bool get canRetry =>
      phase == AppSyncPhase.waiting || phase == AppSyncPhase.error;
}

class AppSyncTracker {
  int _active = 0;
  String? _lastError;

  bool get isActive => _active > 0;

  AppSyncStatus get status {
    if (_active > 0) return const AppSyncStatus.syncing();
    final error = _lastError;
    if (error != null && error.isNotEmpty) {
      return AppSyncStatus.error(error);
    }
    return const AppSyncStatus.synced();
  }

  void startCycle() {
    _lastError = null;
  }

  AppSyncStatus begin() {
    _active += 1;
    return const AppSyncStatus.syncing();
  }

  AppSyncStatus recordError(String message) {
    final normalized = message.trim();
    if (normalized.isNotEmpty) _lastError = normalized;
    return status;
  }

  AppSyncStatus complete() {
    if (_active > 0) _active -= 1;
    return status;
  }

  AppSyncStatus summarize({
    required int waiting,
    required int failed,
  }) {
    if (_active > 0) return const AppSyncStatus.syncing();
    final error = _lastError;
    if (error != null && error.isNotEmpty) {
      return AppSyncStatus.error(error);
    }
    if (failed > 0) {
      return AppSyncStatus.error(
        'Có $failed thao tác chưa gửi được. Chọn Đồng bộ lại để thử lại.',
      );
    }
    if (waiting > 0) return AppSyncStatus.waiting(waiting);
    return const AppSyncStatus.synced();
  }
}

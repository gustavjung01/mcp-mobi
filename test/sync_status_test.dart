import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_field/core/sync/sync_status.dart';

void main() {
  test('sync tracker exposes sending waiting error and synced states', () {
    final tracker = AppSyncTracker();

    tracker.startCycle();
    expect(tracker.begin().phase, AppSyncPhase.syncing);
    expect(tracker.complete().phase, AppSyncPhase.synced);
    expect(
      tracker.summarize(waiting: 2, failed: 0).phase,
      AppSyncPhase.waiting,
    );
    expect(
      tracker.summarize(waiting: 2, failed: 1).phase,
      AppSyncPhase.error,
    );

    tracker.startCycle();
    tracker.begin();
    tracker.recordError('Không gửi được dữ liệu tuyến.');
    tracker.complete();
    expect(tracker.status.phase, AppSyncPhase.error);

    tracker.startCycle();
    expect(tracker.summarize(waiting: 0, failed: 0).phase, AppSyncPhase.synced);
  });
}

# MCP Field — Release checklist

## Gate code

- [ ] `main` mới nhất đã được đối chiếu trước merge.
- [ ] PR CI xanh: format, analyze, test, Android debug, Android release APK/AAB validation, iOS release compile.
- [ ] Không có WebView hoặc direct DB access.
- [ ] Không có secret, keystore, database credential hoặc internal token trong source.
- [ ] Canonical Idempotency-Key vẫn được reuse cho cùng một mutation khi retry.

## Regression nghiệp vụ

- [ ] Chọn hệ thống, đăng nhập, khôi phục phiên.
- [ ] Mở app khi mạng gián đoạn và hiển thị trạng thái dễ hiểu.
- [ ] Hôm nay và 5 mục điều hướng chính.
- [ ] Bắt đầu/tiếp tục/kết thúc phiên đi tuyến.
- [ ] Điểm bán độc lập với Đi tuyến.
- [ ] Check-in: cho phép vị trí, từ chối quyền, GPS chậm/tắt.
- [ ] Ảnh điểm bán: chọn/chụp, preview, upload, lỗi upload, retry.
- [ ] Ra đơn, lưu nháp, gửi đơn, retry cùng intent không tạo đơn trùng.
- [ ] Báo cáo, thử sản phẩm, công việc theo dõi.
- [ ] Mutation chờ vẫn còn sau restart và đồng bộ lại khi có mạng.
- [ ] Hết phiên đăng nhập và thiếu quyền đều dùng ngôn ngữ người dùng.

## Android phát hành

### Gate bắt buộc về signing/version

- [ ] Xác nhận bản đang phát hành tiếp nối signing identity của các bản đã phát hành đến **1.0.4**; mặc định lịch sử là `%USERPROFILE%\.android\debug.keystore`.
- [ ] Không thay keystore/alias/signing mode trong PR nghiệp vụ, UI hoặc release-readiness. Đổi signing chỉ được làm trong migration riêng có test cài đè.
- [ ] Không xóa fallback signing tương thích trong `scripts/build-release.ps1` nếu chưa có migration signing được phê duyệt.
- [ ] Nếu cấu hình keystore khác identity lịch sử, có đủ 4 biến `MCP_ANDROID_*`; không ép Key Manager/app khác gánh signing riêng của MCP.
- [ ] `release-config.json` và `pubspec.yaml` cùng phản ánh version hiện tại trước build.
- [ ] Trước khi `git pull`, `git restore`, drop stash hoặc bỏ local changes ở hai file version, đã đối chiếu version phát hành thật; không được làm mất metadata version chỉ để làm sạch working tree.
- [ ] `MCP_CI_RELEASE_VALIDATION` không được bật khi đóng gói thật.
- [ ] `KM_RELEASE_VERSION` khớp `release-config.json`.
- [ ] Build script tạo cả APK và AAB.
- [ ] APK + `latest.json` được upload cùng version.
- [ ] `verify-release-publication.ps1` PASS sau upload.
- [ ] Cài thử APK mới trên thiết bị Android thật và kiểm tra cập nhật từ bản trước.

## iOS

- [ ] CI `flutter build ios --release --no-codesign` PASS.
- [ ] Bundle identifier là `com.hungphat.mcpfield`.
- [ ] Camera, ảnh và vị trí có usage description.
- [ ] Apple signing/provisioning được cấu hình ngoài repo trước khi archive phân phối.
- [ ] Thiết lập trên iOS không hiển thị luồng tải/cài APK Android.

## Production boundary

Repo mobile không tự deploy backend/DB. Nếu regression chỉ ra lỗi contract MCP API, mở task backend riêng, audit NPP-Platform và deploy theo boundary riêng.

# MCP Field — Lô 7 Runtime Integration Gate

## Mục tiêu

Lô 7 không dùng unit/widget test để thay thế bằng chứng runtime. Gate được tách thành hai lớp:

1. **Device Foundation CI** chạy tự động trên Android emulator và iOS simulator, dùng plugin thật của Flutter/native.
2. **Runtime Integration Gate** chỉ chạy thủ công trên một installation test đã được phê duyệt, gọi MCP API thật và chuỗi MCP -> Công Ty thật.

Không workflow nào trong tài liệu này đồng nghĩa với deploy production, migration database hoặc phát hành app.

## Device Foundation CI

Workflow: `.github/workflows/device-foundation-ci.yml`

Test: `integration_test/device_foundation_test.dart`

Gate này chứng minh trên Android/iOS:

- `FlutterSecureStorage` ghi/đọc/xóa được dữ liệu riêng của test;
- SQLite thật lưu và đọc lại mutation queue sau khi đóng/mở database;
- nháp đơn vẫn còn sau khi đóng/mở database;
- tuyến đã chọn vẫn còn sau khi đóng/mở database;
- ảnh chờ gửi + metadata nằm trong private app storage và đọc lại được;
- dữ liệu test dùng scope/key riêng và được dọn sau khi chạy.

Gate này không gọi production API.

## Runtime Integration Gate

Workflow: `.github/workflows/runtime-integration-gate.yml`

Test: `integration_test/runtime_gate_test.dart`

Workflow chỉ nhận HTTPS API origin của **installation test**. Hai guard bắt buộc:

- input `environment_name` phải bắt đầu bằng `test-`;
- input `guard` phải đúng `APPROVED_TEST_INSTALLATION_ONLY`.

Credential/fixture không nằm trong repo và không truyền trực tiếp trên command line. Workflow tạo một JSON tạm dưới `RUNNER_TEMP`, quyền file `0600`, rồi dùng `--dart-define-from-file`.

### Secret names cần cấu hình ngoài repo

- `MCP_RUNTIME_LOGIN_NAME`
- `MCP_RUNTIME_PASSWORD`
- `MCP_RUNTIME_OWNER_CODE` — chỉ cần nếu tài khoản test yêu cầu mã xác nhận
- `MCP_RUNTIME_ORDER_CUSTOMER_ID`
- `MCP_RUNTIME_ORDER_CUSTOMER_ADDRESS_ID`
- `MCP_RUNTIME_ORDER_VARIANT_ID`
- `MCP_RUNTIME_ONBOARDING_ROUTE_CUSTOMER_ID`
- `MCP_RUNTIME_MEDIA_ROUTE_CUSTOMER_ID`

Không ghi giá trị thật của các biến này vào issue, PR, chat, screenshot hoặc source.

### Chuỗi nghiệp vụ runtime

Gate chạy cùng một contract mobile production:

- health live/ready + auth boundary;
- đăng nhập + đọc lại phiên;
- đọc tuyến, điểm bán, khách Công Ty, báo cáo, phiếu thử, lịch sử, công việc, catalog, đơn, đề xuất;
- CRUD cấu hình mẫu báo cáo và chuyển dữ liệu test sang inactive;
- submit/sync mở hoặc liên kết mã trên fixture test;
- upload ảnh thật qua R2 rồi xóa ảnh vừa tạo;
- lưu đơn vào SQLite queue -> replay thật -> Công Ty;
- gọi lại cùng **đúng Idempotency-Key** và xác nhận không sinh đơn thứ hai;
- tạo/cập nhật tuyến tạm;
- tạo và xóa phiên rỗng;
- thêm/sửa vị trí điểm bán, mở phiên, check-in, cập nhật kết quả ghé;
- báo cáo thị trường, thử sản phẩm, follow-up, thêm khách trong phiên + bỏ qua có lý do;
- kết thúc phiên, đọc lịch sử, hậu kiểm thử sản phẩm;
- tạo snapshot báo cáo, AI phân tích, dựng Word/Excel/PDF/Markdown/JSON/CSV;
- tạo Đề xuất quản lý;
- archive dữ liệu tuyến/điểm bán tạm trong cleanup.

Nếu một contract, permission, adapter hoặc provider chưa sẵn sàng thì workflow phải đỏ. Không đổi sang mock để làm xanh.

## Boundary production

Runtime Integration Gate **không được chạy vào production** chỉ để đóng Issue #42.

Trước khi dùng bất kỳ runtime nào làm bằng chứng Lô 7 phải xác nhận:

1. backend runtime exact release SHA;
2. SHA đó chứa đủ contract mobile đang test;
3. test fixture là dữ liệu test có thể mutate/cleanup;
4. không có migration/deploy ngầm trong workflow;
5. Android và iOS chạy cùng một scenario.

## Audit runtime ngày 2026-09-29

Read-only diagnostic của NPP-Platform xác nhận MCP service đang active, PostgreSQL schema `mcp`, R2/Core Auth/Core Onboarding/Core Sales đều configured.

Tuy nhiên:

- backend source `main`: `2425427eccad1d5419615ef4117495ca9cfc9f70`;
- release MCP VPS gần nhất có evidence exact SHA: `aa3ed0734e4d36a39efe6375b87bc87890ba1158`;
- vì vậy production hiện **không phải bằng chứng** rằng endpoint AI/report mới trên `main` đã được deploy.

Không đổi Matrix sang DONE cho các dòng runtime cho đến khi có workflow run thật trên runtime đúng contract.

## Gate đóng Issue #42

Chỉ đóng #42 khi đồng thời:

- Flutter CI xanh exact head;
- Device Foundation CI Android + iOS xanh exact head;
- Runtime Integration Gate Android + iOS xanh trên installation test được phê duyệt;
- exact backend release SHA được ghi nhận và khớp contract mobile;
- Matrix không còn `MISSING`, `BROKEN` hoặc `PARTIAL` thuộc scope business/runtime;
- release APK/iOS signing và rollout vẫn là thao tác riêng khi Owner yêu cầu.

# MCP Field — Lô 7 Runtime Integration Gate

## Mục tiêu

Lô 7 không dùng unit/widget test để thay thế bằng chứng runtime. Gate có ba lớp độc lập:

1. **Flutter CI** — format/analyze/unit/widget/build.
2. **Device Foundation CI** — Android emulator + iOS simulator, plugin/native storage thật.
3. **Runtime Self-contained CI** — app thật -> MCP API thật -> Công Ty API thật trên một installation test tạm, cô lập hoàn toàn với production.

Workflow manual `.github/workflows/runtime-integration-gate.yml` vẫn giữ để chạy với một installation test bên ngoài khi có nhu cầu. Nó không phải điều kiện để CI tự dựng test installation.

Không gate nào tự deploy production, migrate production DB hoặc phát hành app.

## Device Foundation CI

Workflow: `.github/workflows/device-foundation-ci.yml`

Test: `integration_test/device_foundation_test.dart`

Gate này chứng minh trên Android/iOS:

- `FlutterSecureStorage` ghi/đọc/xóa được dữ liệu test;
- SQLite thật giữ mutation queue sau khi đóng/mở database;
- nháp đơn vẫn còn sau khi đóng/mở database;
- tuyến đã chọn vẫn còn sau khi đóng/mở database;
- ảnh chờ gửi + metadata nằm trong private app storage và đọc lại được;
- cùng một canonical Idempotency-Key vẫn được giữ khi queue được mở lại.

## Runtime Self-contained CI

Workflow: `.github/workflows/runtime-self-contained-ci.yml`

Test: `integration_test/runtime_gate_test.dart`

Runtime này được tạo mới trong từng GitHub Actions job. Android và iOS chạy cùng một kịch bản trên database riêng của job.

### Thành phần thật được chạy trong job

- PostgreSQL test riêng;
- migrations Công Ty thật;
- migrations MCP thật;
- Công Ty API thật từ NPP-Platform `main`;
- MCP API thật từ NPP-Platform `main`;
- workforce auth thật;
- customer onboarding boundary thật;
- Công Ty Sales boundary thật;
- S3-compatible object storage cục bộ cho contract R2;
- deterministic report-analysis adapter cục bộ;
- MCP Field app thật trên Android emulator/iOS simulator.

Object storage và report-analysis adapter chỉ thay provider bên ngoài; **MCP/Công Ty contract, persistence, auth, idempotency và nghiệp vụ không bị mock**.

### Fixture an toàn

NPP-Platform cung cấp `npp-core/api/scripts/prepare-mcp-mobile-runtime-e2e.js`.

Script fixture bắt buộc:

- `NODE_ENV=test`;
- PostgreSQL chỉ được là `localhost`, `127.0.0.1` hoặc `::1`;
- không nhận production DB;
- chỉ tạo dữ liệu trong database ephemeral của CI.

Workforce password, service tokens, object-storage credentials và report-agent token được sinh mới trong từng job, được mask, không commit vào repo và không upload artifact.

### Chuỗi nghiệp vụ runtime

Gate chạy đúng contract mobile production:

- health live/ready + mobile auth boundary;
- đăng nhập + đọc lại phiên;
- đọc tuyến, điểm bán, khách Công Ty, report settings/templates, phiếu thử, lịch sử, công việc, catalog, đơn và Đề xuất;
- CRUD cấu hình mẫu báo cáo;
- tạo/cập nhật tuyến tạm;
- tạo và xóa phiên rỗng;
- thêm/cập nhật/vị trí điểm bán;
- submit/sync mở hoặc liên kết mã khách;
- upload ảnh qua S3/R2 contract rồi xóa ảnh vừa tạo;
- mở phiên, check-in, cập nhật kết quả ghé;
- báo cáo thị trường, thử sản phẩm, follow-up;
- thêm khách trong phiên và bỏ qua có lý do;
- lưu đơn vào SQLite queue -> replay thật qua MCP -> Công Ty;
- gọi lại cùng **đúng Idempotency-Key** và xác nhận không sinh đơn thứ hai;
- kết thúc phiên, đọc lịch sử và hậu kiểm thử sản phẩm;
- tạo snapshot báo cáo;
- gọi endpoint AI report và xác nhận kết quả được persist;
- dựng Word/Excel/PDF/Markdown/JSON và các CSV từ read model thật;
- tạo/list Đề xuất quản lý;
- archive tuyến/điểm bán tạm trong cleanup.

Nếu contract, permission, adapter hoặc persistence sai thì workflow phải đỏ. Không đổi sang mock để làm xanh.

## Runtime manual ngoài CI

Workflow: `.github/workflows/runtime-integration-gate.yml`

Dùng khi có installation test bên ngoài được phê duyệt. Guard bắt buộc:

- tên environment bắt đầu bằng `test-`;
- guard đúng `APPROVED_TEST_INSTALLATION_ONLY`;
- HTTPS cho runtime bên ngoài;
- chỉ loopback `http://127.0.0.1`, `localhost`, `10.0.2.2` được chấp nhận cho environment `test-local-*`.

Không chạy manual mutation gate vào production.

## Production audit 2026-09-29

Read-only diagnostic xác nhận MCP service active, PostgreSQL schema `mcp`, R2, Core Auth, Core Onboarding và Core Sales đều configured.

Production MCP backend đã được deploy/smoke ở exact SHA:

`1d8d78ae0121106b8153d32c42cfb33c3f81c1e7`

Sau đó NPP-Platform `main` tiến lên `e09197c0b64e1a2e7c2e49fb4315c2d9bfe07247`, nhưng diff chỉ thuộc export phía Công Ty web; không thay `mcp/apps/backend/**` hay contract mobile. Vì vậy không deploy MCP lặp lại chỉ để bám thay đổi web.

Production chỉ là bằng chứng deploy/smoke. Runtime Self-contained CI mới là nơi chạy mutation E2E an toàn.

## Gate đóng Issue #42

Chỉ đóng #42 khi đồng thời:

- Flutter CI xanh exact mobile head;
- Device Foundation CI Android + iOS xanh exact mobile head;
- Runtime Self-contained CI Android + iOS xanh;
- workflow ghi lại exact NPP runtime SHA đã checkout;
- Matrix không còn `MISSING`, `BROKEN` hoặc `PARTIAL` thuộc scope nghiệp vụ/runtime;
- release APK/iOS signing và rollout vẫn là thao tác riêng khi Owner yêu cầu.

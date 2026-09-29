# MCP Mobile — Lô 0 Parity Matrix 100%

> Issue: #42  
> Audit date: 2026-09-28  
> Mobile source: `gustavjung01/mcp-mobi@fcf4a3d3d44c4aec9bd2881a46ffe83fdb1eec45`  
> MCP/Công Ty source: `binhnxwjfjxm/NPP-Platform@aa3ed0734e4d36a39efe6375b87bc87890ba1158`

## 1. Kết luận Lô 0

Lô 0 xác nhận **MCP Mobile chưa đạt parity nghiệp vụ 100%**. Issue #31 đóng trước đây không còn được dùng làm bằng chứng hoàn thiện.

Bốn nguyên nhân gốc chi phối phần lớn lỗi hiện tại:

1. **Mobile đã rút gọn nghiệp vụ MCP gốc**: nhiều capability web có contract thật nhưng mobile thiếu hẳn hoặc chỉ có một phần.
2. **Local data layer sai tầng**: mutation queue, order draft và route selection đang dựa vào `FlutterSecureStorage`; SKU/catalog chưa có local cache/index.
3. **Capability + error state chưa canonical**: UI có thể hiện menu/action trong khi client/capability không sẵn sàng; lỗi 404/409/5xx chưa được map đủ theo business code.
4. **CI chưa chứng minh runtime thật**: Flutter CI hiện chủ yếu unit/widget/build với mock/memory store, chưa gate app thật -> MCP API -> Công Ty API.

Không sửa UI/backend trong Lô 0. Tài liệu này là inventory/source-of-truth cho các lô tiếp theo.

## 2. Quy tắc đánh trạng thái

- **DONE**: mobile có flow, contract, permission, persistence/retry và test đủ cho capability hiện tại.
- **PARTIAL**: có flow nhưng thiếu một hoặc nhiều hành vi của MCP gốc.
- **MISSING**: MCP gốc có capability nhưng mobile chưa có.
- **BROKEN**: có code nhưng kiến trúc/runtime hiện tại không đáp ứng contract hoặc có lỗi đã quan sát.
- **PLATFORM-EQUIVALENT**: capability không phải nghiệp vụ nhưng mobile native có cơ chế tương đương hợp lý.

Một dòng chỉ được chuyển sang DONE ở các lô sau khi có regression test và runtime evidence.

## 3. Permission contract đã khóa

User-facing write permissions MCP hiện có:

```text
mcp.route.write
mcp.route-customer.write
mcp.session.write
mcp.session-customer.write
mcp.order.write
mcp.test.write
mcp.report.write
mcp.followup.write
mcp.report-setting.write
```

Integration permissions cho bán hàng Công Ty:

```text
mcp.sales-order.read
mcp.sales-order.create
```

Các thao tác bán hàng Công Ty còn bị scope theo kho `mcp:warehouse:<warehouseId>`.

Mobile không được tự suy ra quyền từ UI. Backend là authority.

## 4. Parity Matrix

| # | Capability MCP gốc | Canonical source/contract | Permission | Mobile hiện tại | Local/offline requirement | Status | Thiếu/hỏng đã khóa |
|---|---|---|---|---|---|---|---|
| 1 | Đăng nhập | `/api/mobile-auth/login` | authenticated contract | Có | Token secure storage | DONE | Cần giữ regression thật khi đổi local DB |
| 2 | Restore phiên đăng nhập | `/api/mobile-auth/me` | authenticated | Có | Token secure storage | DONE | Secure storage ở đây là đúng tầng |
| 3 | Đăng xuất | `/api/mobile-auth/logout` | authenticated | Có | Xóa token/session | DONE | Không được xóa nhầm business queue khi refactor |
| 4 | Tổng quan/Hôm nay | MCP dashboard/local read | read scope | Có tuyến, tiến độ, đơn, test, follow-up | Cache read model | PARTIAL | Thiếu cảnh báo/ưu tiên/runtime health tương đương MCP gốc |
| 5 | Danh sách tuyến cố định | `/api/local-read/mcp-shell` | read scope | Có | Cache tuyến | PARTIAL | Chưa có local DB/cache chuẩn |
| 6 | Chọn tuyến | local UI + route workspace | read | Có | Persist theo installation+employee | PARTIAL | Đã chuyển sang SQLite theo installation+employee; chờ runtime evidence thiết bị |
| 7 | Tạo tuyến | `POST /api/routes` | `mcp.route.write` | Có theo quyền | Queue SQLite | PARTIAL | Đã có form + canonical queue; chờ runtime evidence |
| 8 | Sửa tuyến | `PATCH /api/routes/:id` | `mcp.route.write` | Có theo quyền | Queue SQLite | PARTIAL | Đã có sửa tuyến + retry cùng key; chờ runtime evidence |
| 9 | Archive/xóa tuyến | `POST /api/routes/:id/archive` | `mcp.route.write` | Có theo quyền | Queue SQLite + xác nhận | PARTIAL | Đã có ngừng sử dụng tuyến; chờ runtime evidence |
| 10 | Xem membership điểm bán trong tuyến | shell/read model | read | Có + quản trị theo quyền | Cache | PARTIAL | Đã có quản trị membership; read cache tuyến vẫn cần hoàn thiện |
| 11 | Thêm điểm bán vào tuyến cố định | `POST /api/route-customers` | `mcp.route-customer.write` | Có route-only + active-session option | Queue SQLite | PARTIAL | Đã có canonical flow; chờ runtime evidence |
| 12 | Sửa điểm bán | `PATCH /api/route-customers/:id` | `mcp.route-customer.write` | Có tên/SĐT/khu vực/địa chỉ/thứ tự/ghi chú + GPS | Queue SQLite | PARTIAL | Full edit đã có; chờ runtime evidence |
| 13 | Archive/xóa điểm bán | `POST /api/route-customers/:id/archive` | `mcp.route-customer.write` | Có theo quyền | Queue SQLite + xác nhận | PARTIAL | Đã có loại khỏi tuyến; chờ runtime evidence |
| 14 | Preview tuyến trước phiên | shell + route customer read | read | Có tuyến cố định/preview cơ bản | Cache | PARTIAL | Chưa chung state với route management |
| 15 | Mở phiên | `POST /api/mcp-day/open-session` | `mcp.session.write` | Có, khóa theo quyền | Durable SQLite intent | PARTIAL | Queue đúng tầng; chờ runtime evidence |
| 16 | Tiếp tục phiên active | `/api/mcp-day/data` | read | Có | SQLite selection + server state | PARTIAL | Luồng tiếp tục rõ theo trạng thái; chờ runtime evidence |
| 17 | Kết thúc/chốt phiên | `PATCH /api/mcp-sessions/:id` | `mcp.session.write` | Có status done, khóa theo quyền | Durable SQLite intent | PARTIAL | Đã chung state với hủy/xóa rỗng; chờ runtime evidence |
| 18 | Hủy/chỉnh phiên | `PATCH /api/mcp-sessions/:id` | `mcp.session.write` | Có hủy phiên | Durable SQLite intent | PARTIAL | Hủy phiên đã có; chỉnh ngày/note nâng cao chưa surfaced |
| 19 | Xóa phiên rỗng | `DELETE /api/mcp-sessions/:id` | `mcp.session.write` | Có khi phiên chưa phát sinh tác nghiệp | Durable SQLite intent | PARTIAL | Đã có guard UI + backend authority; chờ runtime evidence |
| 20 | Single-active-session conflict recovery | session lifecycle contract | `mcp.session.write` | Có business message + đổi tuyến/refresh | State refresh | PARTIAL | Không còn generic 409 cho conflict chính; chờ runtime evidence |
| 21 | Check-in | `POST /api/mcp-day/session-customer/checkin` | `mcp.session-customer.write` | Có, khóa theo quyền | Queue SQLite + GPS | PARTIAL | Persistence/quyền đã sửa; chờ runtime evidence |
| 22 | Hoàn tác check-in | cùng contract `checkedIn=false` | `mcp.session-customer.write` | Có | Queue | PARTIAL | Cần runtime test thật |
| 23 | Bỏ qua + lý do | `POST /api/mcp-day/session-customer/status` | `mcp.session-customer.write` | Có | Queue | PARTIAL | Cần canonical reason/settings parity |
| 24 | Thêm điểm bán phát sinh vào phiên | `POST /api/mcp-day/session-customer/add` | `mcp.session-customer.write` | Có, khóa theo quyền | Queue SQLite | PARTIAL | Persistence/quyền đã sửa; chờ runtime evidence |
| 25 | Danh bạ điểm bán | shell/customer read | read | Có | Local searchable cache | PARTIAL | Chưa local DB/index |
| 26 | Danh bạ khách Công Ty | `GET /api/core-customers` | authenticated/scoped | Có card + hồ sơ chi tiết + ra đơn | Cache | PARTIAL | Hồ sơ thao tác đã có; cache danh bạ còn cần hoàn thiện |
| 27 | Hồ sơ điểm bán | outlet/customer read | read | Có + full edit/archive theo quyền | Cache | PARTIAL | Nghiệp vụ quản lý đã có; chờ runtime evidence |
| 28 | GPS điểm bán | route-customer update | `mcp.route-customer.write` | Có lấy/cập nhật vị trí | Queue SQLite | PARTIAL | Queue đúng tầng; cần runtime conflict evidence |
| 29 | Mở Maps | location URL | read | Có | Không | DONE | Native external navigation phù hợp |
| 30 | Ảnh điểm bán: xem | `GET /api/outlet-media/customer-profile` | scoped | Có | Cache metadata | PARTIAL | Cần runtime verify production thật |
| 31 | Ảnh điểm bán: upload | upload-init/finalize | route/customer scope | Có | Pending file store | PARTIAL | Kiến trúc file pending tốt hơn queue JSON nhưng cần device E2E |
| 32 | Ảnh điểm bán: xóa | `POST /api/outlet-media/delete` | scoped | Có | Online/retry | PARTIAL | Chưa real integration gate |
| 33 | Mở/liên kết mã khách | customer verification submit | boundary contract | Có | Queue | PARTIAL | Queue sai tầng; cần end-to-end approval/link evidence |
| 34 | Đồng bộ trạng thái mở/liên kết mã | `POST /api/customer-verifications/sync` | boundary contract | Có | Queue/read refresh | PARTIAL | Cần runtime evidence |
| 35 | Catalog SKU Công Ty | `GET /api/core-sales/products/search` | `mcp.sales-order.read` + warehouse scope | Có local catalog sync + refresh giá hiển thị | **Local catalog bắt buộc** | PARTIAL | Catalog SQLite dùng local-first; giá màn tạo đơn được refresh từ Công Ty, chờ runtime evidence |
| 36 | Variant/unit | `GET /api/core-sales/products/:id/variants` | `mcp.sales-order.read` | Nhóm theo sản phẩm, hiển thị từng quy cách/đơn vị bán | Local cache | PARTIAL | UI đã tách product → variant/unit đúng catalog; chờ device/runtime evidence |
| 37 | Giá bán canonical | core-sales price resolution | `mcp.sales-order.read/create` | Local SKU + fresh price overlay; submit không gửi giá | Cache chỉ tham khảo | PARTIAL | Công Ty vẫn là authority; mobile không gửi price/discount/tax, chờ runtime evidence |
| 38 | Tìm SKU nhanh | web có `mcp-product-local-cache.ts` | read | Tìm SQLite local sau catalog sync | Local indexed search | PARTIAL | Đã có local indexed search; chờ device evidence |
| 39 | Chọn khách để tạo đơn | core customers + address | read | Có picker | Cache | PARTIAL | Chưa dùng local indexed directory |
| 40 | Thêm SKU vào giỏ | order workflow | create later | Có bước Sản phẩm riêng → Giỏ hàng | Draft local | PARTIAL | Add/remove/quantity + draft SQLite đã nối theo variant; chờ device evidence |
| 41 | Giỏ hàng riêng/rà đơn | MCP order create UX | create | Tách Giỏ hàng → Rà đơn → Gửi | Draft local | PARTIAL | Không còn submit trực tiếp từ màn chọn sản phẩm; chờ runtime evidence |
| 42 | Tạo đơn về Công Ty | `POST /api/core-sales/orders` | `mcp.sales-order.create` + warehouse scope | Có result created/queued/failed + business error recovery | Durable mutation | PARTIAL | Contract/payload đã khớp MCP gốc; chưa được nâng DONE trước real MCP → Công Ty runtime evidence |
| 43 | Idempotent retry đơn | canonical key contract | create | Canonical key theo fingerprint; retry reuse exact key | Durable SQLite queue | PARTIAL | SQLite/retry contract có regression test; chờ device/runtime no-duplicate evidence |
| 44 | Đơn chờ gửi | local queue | create | Có trạng thái Chờ gửi + gửi lại | Transactional SQLite | PARTIAL | Kết quả queued không tạo intent mới; chờ device recovery evidence |
| 45 | Danh sách đơn | `GET /api/core-sales/orders` | `mcp.sales-order.read` | Có | Read cache | PARTIAL | Filter/detail chưa parity |
| 46 | Chi tiết đơn + dòng hàng + version | core sales read model | read | Có current detail + lịch sử mọi version/line | Cache | PARTIAL | UI lịch sử phiên bản đã có; chờ runtime evidence với đơn thật nhiều version |
| 47 | Báo cáo thị trường | session-customer report | `mcp.report.write` | Có form cấu trúc + mẫu dùng sẵn | SQLite queue | PARTIAL | Payload/retry đã bám canonical contract; chờ device/runtime evidence |
| 48 | Đối thủ | report settings + report payload | `mcp.report.write` | Có khu vực Đối thủ theo group/item canonical | Cache settings | PARTIAL | Grouping/payload đã parity MCP gốc; chờ runtime evidence |
| 49 | SP khách đang dùng | report settings groups | `mcp.report.write` | Có khu vực Sản phẩm khách đang dùng theo từng nhóm | Cache settings | PARTIAL | UI nghiệp vụ đã tách rõ; chờ runtime evidence |
| 50 | Cấu hình nhóm mẫu báo cáo | `POST/PATCH /api/mcp-report-setting-groups` | `mcp.report-setting.write` | Có thêm/sửa/bật-tắt theo quyền | Cache + online mutation | PARTIAL | Dùng canonical Idempotency-Key và retry cùng intent; chờ runtime evidence |
| 51 | Cấu hình item mẫu báo cáo | `POST/PATCH /api/mcp-report-settings` | `mcp.report-setting.write` | Có thêm/sửa/bật-tắt theo nhóm | Cache + online mutation | PARTIAL | Mobile đã có entry point quản trị; chờ runtime evidence |
| 52 | Report templates | `GET /api/mcp-report-templates` | read | Có chọn mẫu và đổ nội dung vào báo cáo | Cache | PARTIAL | Canonical template read đã nối; chờ runtime evidence |
| 53 | Thử sản phẩm tại điểm bán | session-customer test | `mcp.test.write` | Có chọn phiếu/sản phẩm hoặc nhập tay fallback | SQLite queue | PARTIAL | Payload fileId/productId/name bám canonical contract; chờ runtime evidence |
| 54 | Phiếu/file thử sản phẩm + sản phẩm trong phiếu | `GET /api/mcp-day/test-options` | read | Có picker phiếu và sản phẩm trong phiếu | Cache | PARTIAL | Read model đã nối đúng test_files/test_file_products; chờ runtime evidence |
| 55 | Hậu kiểm thử SP | `POST /api/field-checks/result` | `mcp.test.write` | Có Bình thường/Cơ hội/Rủi ro + lịch sử | SQLite queue | PARTIAL | Retry cùng canonical key đã có regression test; chờ device/API integration |
| 56 | Tạo follow-up | session-customer followup | `mcp.followup.write` | Có | Queue | PARTIAL | Queue sai tầng |
| 57 | Danh sách Kế hoạch/Công việc | followup read | read | Có | Cache | PARTIAL | Cần local searchable/filter parity |
| 58 | Priority/owner/due/overdue/source | followup model | read/write | Có phần lớn | Cache | PARTIAL | Chưa gate đủ dữ liệu qua nhiều phiên |
| 59 | Lịch sử phiên | local read/sessions | read | Có filter route/status/days | Cache | PARTIAL | Cần chi tiết transition/action parity |
| 60 | Chi tiết báo cáo phiên | session report read | read | Có | Cache | PARTIAL | Cần kiểm toàn dữ liệu orders/tests/reports/followups/skips |
| 61 | Snapshot báo cáo phiên | `POST /api/mcp-session-report` | `mcp.report.write` | Không chủ động tạo | Queue | MISSING | MCP backend có contract |
| 62 | AI phân tích báo cáo phiên | `/api/mcp-session-report/analyze` + ai-result | `mcp.report.write` | Không | Online only | MISSING | User-facing MCP capability |
| 63 | Xuất báo cáo phiên Word/Excel/PDF/export | session report export routes | read | Không | Online | MISSING | User-facing capability MCP web |
| 64 | CSV exports: phiên/đơn/điểm bán/report/test/follow-up | export routes | read | Không | Online | MISSING | User-facing capability MCP web |
| 65 | Đề xuất quản lý | `/api/management-proposals` | `mcp.report.write` | Có role-gated | Queue | PARTIAL | Có submit/list/resubmit; cần integration thật |
| 66 | Capability-state theo quyền/cấu hình | access + backend readiness | permission-dependent | Rời rạc | Local session capability map | BROKEN | Không có registry canonical |
| 67 | Menu/action khi capability null | mobile More/AppShell | n/a | Một số menu luôn render | n/a | BROKEN | Có thể bấm không phản hồi |
| 68 | Canonical error mapping | API contract | n/a | Mỗi client tự map | Persist error code | BROKEN | 404/409/503 dễ bị gom thông báo chung |
| 69 | Mutation queue | shared canonical queue | n/a | Có | Transactional SQLite | PARTIAL | SQLite + reopen tests xanh; chờ device evidence |
| 70 | Order draft | local draft | n/a | Có | Transactional SQLite | PARTIAL | SQLite + reopen tests xanh; chờ device evidence |
| 71 | Route selection persistence | local selection | n/a | Có | Transactional SQLite | PARTIAL | SQLite + restart tests xanh; chờ device evidence |
| 72 | Pending photo binary | private app files | n/a | Có | Private file store | PARTIAL | Hướng đúng; cần metadata transactional |
| 73 | Background sync | replay services | permissions | Có | DB queue | PARTIAL | Nhiều `catch (_)` nuốt lỗi; thiếu global sync center |
| 74 | Trạng thái sync người dùng hiểu được | waiting/sending/error/synced | n/a | Có cục bộ | DB queue | PARTIAL | Chưa thống nhất toàn app |
| 75 | Cài đặt native/update app | mobile Settings | n/a | Có | Local | PLATFORM-EQUIVALENT | PWA install không áp dụng native; native update là tương đương |
| 76 | Real Android E2E | app -> MCP -> Công Ty | all | Chưa có CI gate | Test environment | MISSING | CI xanh hiện không chứng minh production-like flow |
| 77 | iOS flow gate | app -> MCP | all | Compile + widget | Test environment | PARTIAL | Chưa integration tương đương Android |

## 5. Root-cause register cho lỗi đã quan sát

### RC-01 — Ra đơn “quá sơ sài”

**Evidence source**
- Mobile `CreateOrderPage` có cart nội bộ nhưng catalog + cart + note + submit nằm chung một màn.
- MCP web đã tách product selection/cart/order flow và có local product cache.

**Root cause**
- Mobile port theo component tối thiểu, không port theo workflow nghiệp vụ.

**Owner tầng sửa**
- Mobile feature architecture + local catalog layer. Không cần vá backend chỉ để tạo thêm màn.

### RC-02 — SKU tìm chậm / phải gọi mạng

**Evidence source**
- Mobile `OrderDataClient` gọi trực tiếp `/api/core-sales/products/search`.
- Không có local SKU store/index trong mobile.
- MCP web có `mcp-product-local-cache.ts`.

**Root cause**
- Thiếu read-cache architecture cho catalog.

**Owner tầng sửa**
- Lô 1 local data foundation + Lô 3 order workflow.

### RC-03 — “Không lưu được trên thiết bị”

**Evidence source**
- `SecureMutationQueueStore`, `SecureOrderOfflineStore`, `SecureRouteSelectionStore` đều dùng `FlutterSecureStorage`.
- Queue/draft là business data có thể lớn và cập nhật thường xuyên, không phải credential.

**Root cause**
- Chọn sai persistence primitive.

**Owner tầng sửa**
- Lô 1: transactional local DB; secure storage chỉ giữ token/credential.

### RC-04 — Không sửa được thông tin khách/điểm bán

**Evidence source**
- Backend có `PATCH /api/route-customers/:id` với full route-customer update.
- Mobile chỉ nối update location.

**Root cause**
- Thiếu capability mobile, backend không thiếu contract.

**Owner tầng sửa**
- Lô 2 mobile route/customer management.

### RC-05 — Kết thúc phiên rồi không rõ mở phiên mới ở đâu

**Evidence source**
- Mobile có open + finish; không có cancel/update/delete-empty management.
- Backend có full lifecycle + single-active-session rule.
- MCP web có session manager/recovery messaging.

**Root cause**
- Mobile chỉ implement happy-path transition.

**Owner tầng sửa**
- Lô 2 session state machine + recovery UX; backend giữ authority.

### RC-06 — Gửi đơn về Công Ty lỗi / “Dữ liệu đang xung đột”

**Evidence source**
- Mobile gọi canonical `POST /api/core-sales/orders`.
- Backend dùng `mcp.sales-order.create` + warehouse scope và forward canonical Công Ty business errors.
- Mobile error map chỉ biết một số code; các code khác rơi về server generic message.
- 409 có thể đến từ business conflict/idempotency/customer/address/catalog state.

**Root cause**
- Không phải endpoint giả; canonical payload đã khóa ở khách + địa chỉ + variant + số lượng + ghi chú. Lỗi còn lại phụ thuộc dữ liệu/runtime và business code Công Ty.

**Owner tầng sửa**
- Lô 3 đã tách workflow và map các lỗi order/integration chính thành hành động cụ thể. Chỉ sửa backend nếu real integration chứng minh contract/backend sai; Lô 7 vẫn phải chứng minh MCP -> Công Ty trên runtime thật.

### RC-07 — “Tài nguyên không sẵn sàng”, mục bấm không chạy

**Evidence source**
- `MorePage` tạo nhiều menu item bất kể callback có null; chỉ Đề xuất được conditionally render.
- AppShell khởi tạo client/callback phụ thuộc session/profile/permission/config.
- Các client không dùng một capability registry chung.

**Root cause**
- UI capability state phân tán.

**Owner tầng sửa**
- Lô 6 capability registry + consistent disabled/hidden/error state.

### RC-08 — CI xanh nhưng app thật còn nhiều lỗi

**Evidence source**
- Flutter CI chạy analyze/unit/widget/build.
- Tests dùng nhiều MockClient/MemoryStore.
- Không có required gate cài app emulator/device rồi gọi test MCP + test Công Ty.

**Root cause**
- Test pyramid thiếu integration/runtime layer.

**Owner tầng sửa**
- Lô 7 integration/release gate.

## 6. Source inventory đã audit

### MCP web surface

```text
/
 /mcp
 /routes
 /visits
 /mcp/sessions
 /customers
 /customers/onboarding
 /orders
 /reports
 /field-checks
 /plans
 /mcp-setting
 /settings
```

Có thêm user-facing capability qua API/component:
- CRUD tuyến;
- CRUD/archive điểm bán;
- session lifecycle;
- report templates/settings;
- session report snapshot/AI/export;
- management proposals;
- CSV/PDF/Word/Excel exports;
- outlet media;
- Core sales catalog/order bridge.

### Mobile surface hiện tại

```text
Hôm nay
Đi tuyến
Điểm bán
Đơn hàng
Thêm
  - Tuyến cố định
  - Lịch sử phiên
  - Báo cáo
  - Kết quả thử sản phẩm
  - Kế hoạch & Công việc
  - Đề xuất (role-gated)
  - Mở hoặc liên kết mã khách
  - Thiết lập
```

Mobile đã có entry point quản trị tuyến/điểm bán và report-setting CRUD; report template đã dùng trong form báo cáo. Export/AI vẫn thuộc các lô sau.

## 7. Lỗ hổng test Lô 0 khóa lại

Các gate bắt buộc phải được thêm ở các lô sau:

1. Local DB migration và restart recovery.
2. SKU sync -> offline local search.
3. Open/close/cancel/recover session state.
4. Edit/archive route/customer theo permission.
5. App thật -> MCP test backend -> Công Ty test backend tạo đơn.
6. 409 business-code matrix.
7. Retry cùng canonical key không duplicate.
8. Capability unavailable/no-permission/not-configured/offline states.
9. Report/test/followup restart + replay.
10. Media pending binary restart/retry.
11. Android emulator/device E2E.
12. iOS equivalent integration gate khi runner cho phép.

## 8. Gate Lô 0

Lô 0 được coi là hoàn tất khi:

- inventory không còn capability MCP user-facing chưa được kê;
- mỗi capability có source/contract/permission/mobile status;
- root cause của các lỗi đang thấy được phân tầng;
- không sửa code nghiệp vụ trong cùng lô audit;
- matrix được review trên PR từ exact mobile main;
- Issue #42 trỏ tới matrix này làm source-of-truth.

## 9. Thứ tự tiếp theo đã khóa

Sau merge Lô 0:

1. **Lô 1 — Local Data & Sync Foundation** trước.
2. Không sửa order UI, route UI hoặc backend chắp vá trước khi Lô 1 xong.
3. Lô 2 mới làm Tuyến/Phiên/Điểm bán/Khách.
4. Lô 3 làm lại Đơn hàng 100% trên local catalog foundation.
5. Lô 4–7 theo Issue #42.

Mọi PR sau phải cập nhật trạng thái từng dòng matrix; không được đóng Issue #42 khi còn bất kỳ dòng MISSING/PARTIAL/BROKEN nào thuộc business capability.

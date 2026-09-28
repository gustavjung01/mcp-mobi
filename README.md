# MCP Field

Ứng dụng Flutter native cho nhân viên thị trường. Android và iOS dùng chung codebase; app gọi MCP API, không truy cập PostgreSQL trực tiếp và không chứa server secret.

## Môi trường phát triển

- Flutter 3.47.2
- Java 17 cho Android
- Xcode/macOS cho iOS
- Chạy `flutter pub get` trước khi build
- Chạy local bằng `flutter run`

Profile hệ thống chỉ lưu địa chỉ MCP API của installation và dữ liệu phiên cần thiết. Không đưa database credential, API key hoặc token nội bộ vào source.

## Kiểm tra trước khi merge

CI bắt buộc chạy:

- `dart format lib test`
- `flutter analyze`
- `flutter test`
- Android debug APK
- Android release APK + AAB ở chế độ validation
- iOS release compile với `--no-codesign`

CI release Android chỉ dùng debug signing khi biến `MCP_CI_RELEASE_VALIDATION=true` được đặt ngay trong workflow. Artifact đó chỉ để kiểm tra compile, không được phát hành.

## Đóng gói Android để phát hành

Release thật bắt buộc dùng keystore riêng qua biến môi trường, không lưu secret hoặc keystore trong repo:

- `MCP_ANDROID_KEYSTORE`
- `MCP_ANDROID_KEYSTORE_PASSWORD`
- `MCP_ANDROID_KEY_ALIAS`
- `MCP_ANDROID_KEY_PASSWORD`
- `KM_RELEASE_VERSION`
- `KM_RELEASE_NOTES` (không bắt buộc)

`KM_RELEASE_VERSION` phải khớp `release-config.json`.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-release.ps1 `
  -ApiBaseUrl <public-mcp-api-origin> `
  -UpdateBaseUrl <public-update-base-url>
```

Kết quả nằm trong `dist/android-release/`:

- APK ký production để cập nhật trực tiếp
- AAB ký production để phát hành qua store khi cần
- `latest.json` chứa version, build number, URL APK, dung lượng và SHA-256

Sau khi upload APK và `latest.json` lên nơi tải công khai, chạy:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify-release-publication.ps1 `
  -UpdateBaseUrl <public-update-base-url>
```

## iOS

Kiểm tra compile không ký:

```bash
flutter build ios --release --no-codesign
```

Phát hành iOS cần Apple signing/provisioning ở máy hoặc hệ thống phát hành được cấp quyền. Credential Apple không lưu trong repo. Màn Thiết lập trên iPhone/iPad không dùng luồng tải APK của Android.

## Phạm vi Lô 6

Push notification/deep link chưa được nối vì audit backend hiện tại chưa có mobile device-token/push contract hoặc deep-link contract dành cho MCP Mobile. Không thêm dependency hoặc luồng giả khi chưa có source-of-truth.

Checklist regression/phát hành: `docs/release-checklist.md`.

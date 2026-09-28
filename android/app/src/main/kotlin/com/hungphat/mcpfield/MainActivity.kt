package com.hungphat.mcpfield

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val updateChannel = "com.hungphat.mcpfield/app_update"
    private val updateExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            updateChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "currentVersion" -> {
                    val info = packageManager.getPackageInfo(packageName, 0)
                    result.success(info.versionName ?: "")
                }

                "supportsDirectInstall" -> {
                    result.success(true)
                }

                "canInstallPackages" -> {
                    result.success(canInstallPackages())
                }

                "openInstallPermissionSettings" -> {
                    openInstallPermissionSettings()
                    result.success(null)
                }

                "downloadAndInstall" -> {
                    val url = call.argument<String>("url")?.trim().orEmpty()
                    val sha256 = call.argument<String>("sha256")
                        ?.trim()
                        ?.lowercase()
                        .orEmpty()
                    downloadAndInstall(url, sha256, result)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        updateExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun canInstallPackages(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
    }

    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:$packageName"),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun downloadAndInstall(
        rawUrl: String,
        expectedSha256: String,
        result: MethodChannel.Result,
    ) {
        val parsed = runCatching { URI(rawUrl) }.getOrNull()
        if (
            parsed == null ||
            !parsed.scheme.equals("https", ignoreCase = true) ||
            parsed.host.isNullOrBlank()
        ) {
            result.error(
                "UPDATE_URL_INVALID",
                "Địa chỉ tải bản cập nhật chưa hợp lệ.",
                null,
            )
            return
        }
        if (!expectedSha256.matches(Regex("^[0-9a-f]{64}$"))) {
            result.error(
                "HASH_INVALID",
                "Thông tin kiểm tra gói cập nhật chưa hợp lệ.",
                null,
            )
            return
        }
        if (!canInstallPackages()) {
            result.error(
                "INSTALL_PERMISSION_REQUIRED",
                "Cần cho phép MCP Field cài đặt ứng dụng từ nguồn này.",
                null,
            )
            return
        }

        updateExecutor.execute {
            try {
                val updateDir = File(cacheDir, "updates")
                if (!updateDir.exists() && !updateDir.mkdirs()) {
                    throw IllegalStateException("Không chuẩn bị được nơi lưu bản cập nhật.")
                }
                val temporary = File(updateDir, "mcp-field-update.apk.part")
                val target = File(updateDir, "mcp-field-update.apk")
                temporary.delete()
                target.delete()

                val connection = URL(rawUrl).openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connectTimeout = 15_000
                connection.readTimeout = 60_000
                connection.instanceFollowRedirects = true
                connection.setRequestProperty("Accept", "application/vnd.android.package-archive")
                connection.connect()

                if (connection.responseCode !in 200..299) {
                    connection.disconnect()
                    throw IllegalStateException("Không tải được bản cập nhật.")
                }

                val digest = MessageDigest.getInstance("SHA-256")
                BufferedInputStream(connection.inputStream).use { input ->
                    FileOutputStream(temporary).use { output ->
                        val buffer = ByteArray(64 * 1024)
                        while (true) {
                            val read = input.read(buffer)
                            if (read < 0) break
                            if (read == 0) continue
                            digest.update(buffer, 0, read)
                            output.write(buffer, 0, read)
                        }
                        output.fd.sync()
                    }
                }
                connection.disconnect()

                val actualSha256 = digest.digest().joinToString("") {
                    "%02x".format(it)
                }
                if (!actualSha256.equals(expectedSha256, ignoreCase = true)) {
                    temporary.delete()
                    runOnUiThread {
                        result.error(
                            "HASH_MISMATCH",
                            "Gói cập nhật không vượt qua bước kiểm tra an toàn.",
                            null,
                        )
                    }
                    return@execute
                }

                if (!temporary.renameTo(target)) {
                    temporary.copyTo(target, overwrite = true)
                    temporary.delete()
                }

                val contentUri = FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    target,
                )
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(
                        contentUri,
                        "application/vnd.android.package-archive",
                    )
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }

                runOnUiThread {
                    try {
                        startActivity(intent)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error(
                            "INSTALLER_OPEN_FAILED",
                            "Không mở được bước cài đặt bản cập nhật.",
                            null,
                        )
                    }
                }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        "DOWNLOAD_FAILED",
                        "Không tải được bản cập nhật.",
                        null,
                    )
                }
            }
        }
    }
}

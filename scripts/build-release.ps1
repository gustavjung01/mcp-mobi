param(
    [Parameter(Mandatory = $false)]
    [string]$Flutter = "flutter",
    [Parameter(Mandatory = $true)]
    [string]$ApiBaseUrl,
    [Parameter(Mandatory = $true)]
    [string]$UpdateBaseUrl
)

$ErrorActionPreference = "Stop"

$version = $env:KM_RELEASE_VERSION
if ([string]::IsNullOrWhiteSpace($version)) {
    throw "KM_RELEASE_VERSION is required."
}
if ($version -notmatch '^\d+\.\d+\.\d+$') {
    throw "MCP Field release version must use major.minor.patch."
}

$ApiBaseUrl = $ApiBaseUrl.Trim().TrimEnd("/")
$UpdateBaseUrl = $UpdateBaseUrl.Trim().TrimEnd("/")
$apiUri = $null
$updateUri = $null
if (-not [Uri]::TryCreate($ApiBaseUrl, [UriKind]::Absolute, [ref]$apiUri) -or
    $apiUri.Scheme -ne "https" -or
    $apiUri.AbsolutePath -ne "/") {
    throw "ApiBaseUrl must be the root public HTTPS origin of the MCP backend."
}
if (-not [Uri]::TryCreate($UpdateBaseUrl, [UriKind]::Absolute, [ref]$updateUri) -or
    $updateUri.Scheme -ne "https") {
    throw "UpdateBaseUrl must be a public HTTPS URL."
}
if ($updateUri.Host.EndsWith(".r2.cloudflarestorage.com", [StringComparison]::OrdinalIgnoreCase)) {
    throw "UpdateBaseUrl must not use the private R2 S3 endpoint. Use the public R2 download URL or custom domain."
}

$releaseConfigPath = Join-Path $PSScriptRoot "..\release-config.json"
$releaseConfig = Get-Content -LiteralPath $releaseConfigPath -Raw | ConvertFrom-Json
if ($releaseConfig.version -ne $version) {
    throw "release-config.json version $($releaseConfig.version) does not match KM_RELEASE_VERSION $version."
}

$parts = $version.Split(".")
$major = [int]$parts[0]
$minor = [int]$parts[1]
$patch = [int]$parts[2]
if ($minor -ge 1000 -or $patch -ge 1000) {
    throw "Minor and patch versions must stay below 1000 for Android build numbers."
}
$buildNumber = ($major * 1000000) + ($minor * 1000) + $patch
if ($buildNumber -le 0 -or $buildNumber -gt 2100000000) {
    throw "Calculated Android build number is outside the supported range."
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$outputDir = Join-Path $root "dist\android-release"
$apkName = "MCP-Field-$version.apk"
$apkPath = Join-Path $outputDir $apkName
$manifestPath = Join-Path $outputDir "latest.json"

if (Test-Path -LiteralPath $outputDir) {
    Remove-Item -LiteralPath $outputDir -Recurse -Force
}
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

Push-Location $root
try {
    & $Flutter clean
    if ($LASTEXITCODE -ne 0) { throw "flutter clean failed." }

    & $Flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed." }

    & $Flutter build apk --release "--build-name=$version" "--build-number=$buildNumber" "--dart-define=MCP_API_BASE_URL=$ApiBaseUrl" "--dart-define=MCP_UPDATE_BASE_URL=$UpdateBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw "flutter build apk --release failed." }
}
finally {
    Pop-Location
}

$sourceApk = Join-Path $root "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path -LiteralPath $sourceApk)) {
    throw "Release APK was not produced at $sourceApk."
}

Copy-Item -LiteralPath $sourceApk -Destination $apkPath -Force
$apk = Get-Item -LiteralPath $apkPath
$sha256 = (Get-FileHash -LiteralPath $apkPath -Algorithm SHA256).Hash.ToLowerInvariant()
$releaseNotes = if ([string]::IsNullOrWhiteSpace($env:KM_RELEASE_NOTES)) {
    "Cập nhật và cải thiện ứng dụng."
} else {
    $env:KM_RELEASE_NOTES.Trim()
}

$manifest = [ordered]@{
    schemaVersion = 1
    version = $version
    buildNumber = $buildNumber
    apk = $apkName
    url = "$UpdateBaseUrl/$apkName"
    size = $apk.Length
    sha256 = $sha256
    releaseNotes = $releaseNotes
    publishedAt = (Get-Date).ToUniversalTime().ToString("o")
}

$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

Write-Host "MCP Field release ready"
Write-Host "Version: $version"
Write-Host "Build number: $buildNumber"
Write-Host "APK: $apkPath"
Write-Host "Manifest: $manifestPath"

Write-Host "After publishing latest.json and the APK to R2, verify the public update path:"
Write-Host "powershell -ExecutionPolicy Bypass -File scripts\verify-release-publication.ps1 -UpdateBaseUrl <public-update-url>"

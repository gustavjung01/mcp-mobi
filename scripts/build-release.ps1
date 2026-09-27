param(
    [Parameter(Mandatory = $false)]
    [string]$Flutter = "flutter",
    [Parameter(Mandatory = $false)]
    [string]$UpdateBaseUrl = "https://pub-7d2987fab97d4e3ebb2021a823973862.r2.dev/mcp-filed",
    [Parameter(Mandatory = $false)]
    [string]$ApiBaseUrl = "https://68.233.111.135"
)

$ErrorActionPreference = "Stop"

$version = $env:KM_RELEASE_VERSION
if ([string]::IsNullOrWhiteSpace($version)) {
    throw "KM_RELEASE_VERSION is required."
}
if ($version -notmatch '^\d+\.\d+\.\d+$') {
    throw "MCP Field release version must use major.minor.patch."
}

$UpdateBaseUrl = $UpdateBaseUrl.Trim().TrimEnd("/")
$ApiBaseUrl = $ApiBaseUrl.Trim().TrimEnd("/")
if ($UpdateBaseUrl -notmatch '^https://') {
    throw "UpdateBaseUrl must be a public HTTPS URL."
}
if ($ApiBaseUrl -notmatch '^https://') {
    throw "ApiBaseUrl must be a public HTTPS URL."
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

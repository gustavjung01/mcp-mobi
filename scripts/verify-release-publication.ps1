param(
    [Parameter(Mandatory = $true)]
    [string]$UpdateBaseUrl,
    [Parameter(Mandatory = $false)]
    [string]$ExpectedVersion = $env:KM_RELEASE_VERSION
)

$ErrorActionPreference = "Stop"

$UpdateBaseUrl = $UpdateBaseUrl.Trim().TrimEnd("/")
$uri = $null
if (-not [Uri]::TryCreate($UpdateBaseUrl, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne "https") {
    throw "UpdateBaseUrl must be a public HTTPS URL."
}
if ($uri.Host.EndsWith(".r2.cloudflarestorage.com", [StringComparison]::OrdinalIgnoreCase)) {
    throw "UpdateBaseUrl points to the private R2 S3 endpoint. Use the public R2 download URL or custom domain."
}

$manifestUrl = "$UpdateBaseUrl/latest.json"
Write-Host "Checking published manifest..."
try {
    $manifest = Invoke-RestMethod -Uri $manifestUrl -Method Get -TimeoutSec 20
}
catch {
    throw "Published latest.json is not reachable from the public update URL."
}

$version = [string]$manifest.version
$apkUrl = [string]$manifest.url
$sha256 = ([string]$manifest.sha256).ToLowerInvariant()
if ([string]::IsNullOrWhiteSpace($version) -or
    [string]::IsNullOrWhiteSpace($apkUrl) -or
    $sha256 -notmatch '^[0-9a-f]{64}$') {
    throw "Published latest.json is invalid."
}
if (-not [string]::IsNullOrWhiteSpace($ExpectedVersion) -and $version -ne $ExpectedVersion.Trim()) {
    throw "Published version $version does not match expected version $($ExpectedVersion.Trim())."
}

$apkUri = $null
if (-not [Uri]::TryCreate($apkUrl, [UriKind]::Absolute, [ref]$apkUri) -or $apkUri.Scheme -ne "https") {
    throw "Published APK URL is invalid."
}

$tempApk = Join-Path ([IO.Path]::GetTempPath()) "mcp-field-publication-check-$([Guid]::NewGuid().ToString('N')).apk"
try {
    Write-Host "Downloading published APK for SHA-256 verification..."
    Invoke-WebRequest -Uri $apkUri.AbsoluteUri -OutFile $tempApk -TimeoutSec 120
    $actualSha256 = (Get-FileHash -LiteralPath $tempApk -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualSha256 -ne $sha256) {
        throw "Published APK SHA-256 does not match latest.json."
    }
}
finally {
    if (Test-Path -LiteralPath $tempApk) {
        Remove-Item -LiteralPath $tempApk -Force
    }
}

Write-Host "Public MCP Field update publication verified."
Write-Host "Version: $version"

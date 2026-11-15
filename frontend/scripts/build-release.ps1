[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ConfigFile,
    [Parameter(Mandatory = $true)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$BuildName,
    [Parameter(Mandatory = $true)][ValidateRange(1, 2100000000)][int]$BuildNumber,
    [ValidateSet('apk', 'appbundle')][string]$Artifact = 'apk',
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
$frontendRoot = Split-Path -Parent $PSScriptRoot
$configPath = (Resolve-Path -LiteralPath $ConfigFile).Path
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if ($config.APP_ENV -notin @('staging', 'production')) {
    throw 'APP_ENV must be staging or production.'
}
if ([string]$config.USE_MOCK -cne 'false' -or [string]$config.KAKAO_FAKE_LOGIN -cne 'false') {
    throw 'Set USE_MOCK=false and KAKAO_FAKE_LOGIN=false explicitly.'
}
$apiUri = $null
if (-not [Uri]::TryCreate([string]$config.API_BASE_URL, [UriKind]::Absolute, [ref]$apiUri) -or
    $apiUri.Scheme -ne 'https' -or [string]::IsNullOrWhiteSpace($apiUri.Host) -or
    $apiUri.Host.EndsWith('.invalid') -or $apiUri.UserInfo -or $apiUri.Query -or $apiUri.Fragment -or
    $apiUri.AbsolutePath.TrimEnd('/') -ne '/api/v1') {
    throw 'Set a real HTTPS API_BASE_URL ending in /api/v1, without credentials or query.'
}
if ($config.PSObject.Properties.Name -contains 'KAKAO_AUTH') {
    throw 'Remove obsolete KAKAO_AUTH. Real builds always use Kakao authentication.'
}
foreach ($flag in @('STORIES_MONTH_API', 'ACCOUNT_DELETION_API')) {
    if ([string]$config.$flag -cnotin @('true', 'false')) {
        throw "Set $flag explicitly to true or false."
    }
}
if ([string]::IsNullOrWhiteSpace([string]$config.KAKAO_NATIVE_APP_KEY)) {
    throw 'Release requires KAKAO_NATIVE_APP_KEY.'
}
if ($ValidateOnly) {
    Write-Output 'Build config valid. Signing, server connectivity and feature readiness are not verified.'
    return
}
if (-not (Test-Path -LiteralPath (Join-Path $frontendRoot 'android/key.properties'))) {
    throw 'Configure android/key.properties first. See RELEASE.md.'
}

Push-Location $frontendRoot
try {
    $commit = (& git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read source commit.' }
    $changes = & git status --porcelain --untracked-files=normal
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect source state.' }
    if ($changes) { throw 'Commit the intended changes before producing a traceable release build.' }
    & flutter build $Artifact --release "--dart-define-from-file=$configPath" "--build-name=$BuildName" "--build-number=$BuildNumber"
    if ($LASTEXITCODE -ne 0) { throw 'Flutter release build failed.' }
    $relativeArtifact = if ($Artifact -eq 'apk') {
        'build/app/outputs/flutter-apk/app-release.apk'
    } else {
        'build/app/outputs/bundle/release/app-release.aab'
    }
    $artifactPath = Join-Path $frontendRoot $relativeArtifact
    if (-not (Test-Path -LiteralPath $artifactPath)) { throw 'Expected build artifact was not found.' }
    $record = [ordered]@{
        version = $BuildName
        buildNumber = $BuildNumber
        commit = $commit
        environment = $config.APP_ENV
        artifact = $relativeArtifact
        sha256 = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash
        createdUtc = [DateTime]::UtcNow.ToString('o')
        storiesMonthApi = $config.STORIES_MONTH_API
        accountDeletionApi = $config.ACCOUNT_DELETION_API
        deviceQA = 'NOT_RUN'
    }
    # 주소, 앱 키, 서명 비밀번호는 기록하지 않는다.
    $record | ConvertTo-Json | Set-Content -LiteralPath "$artifactPath.build-info.json" -Encoding UTF8
    Write-Output "Built $relativeArtifact with a build-info.json record. Device QA remains required."
} finally {
    Pop-Location
}

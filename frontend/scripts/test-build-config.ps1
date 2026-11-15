$ErrorActionPreference = 'Stop'
$buildScript = Join-Path $PSScriptRoot 'build-release.ps1'
$temporaryConfig = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString() + '.json')
$cases = @(
    @{ Name = 'valid staging'; Changes = @{}; Accept = $true },
    @{ Name = 'valid production'; Changes = @{ APP_ENV = 'production' }; Accept = $true },
    @{ Name = 'mock enabled'; Changes = @{ USE_MOCK = 'true' }; Accept = $false },
    @{ Name = 'fake login enabled'; Changes = @{ KAKAO_FAKE_LOGIN = 'true' }; Accept = $false },
    @{ Name = 'http endpoint'; Changes = @{ API_BASE_URL = 'http://example.com/api/v1' }; Accept = $false },
    @{ Name = 'template endpoint'; Changes = @{ API_BASE_URL = 'https://replace-me.invalid/api/v1' }; Accept = $false },
    @{ Name = 'credential URL'; Changes = @{ API_BASE_URL = 'https://user:pass@example.com/api/v1' }; Accept = $false },
    @{ Name = 'query URL'; Changes = @{ API_BASE_URL = 'https://example.com/api/v1?key=test' }; Accept = $false },
    @{ Name = 'wrong path'; Changes = @{ API_BASE_URL = 'https://example.com' }; Accept = $false },
    @{ Name = 'unknown environment'; Changes = @{ APP_ENV = 'dev' }; Accept = $false },
    @{ Name = 'missing feature flag'; Changes = @{ ACCOUNT_DELETION_API = $null }; Accept = $false },
    @{ Name = 'missing Kakao key'; Changes = @{ KAKAO_AUTH = 'true' }; Accept = $false }
)
try {
    foreach ($case in $cases) {
        $config = @{
            APP_ENV = 'staging'; API_BASE_URL = 'https://example.com/api/v1'
            USE_MOCK = 'false'; KAKAO_FAKE_LOGIN = 'false'; KAKAO_AUTH = 'false'
            STORIES_MONTH_API = 'true'; ACCOUNT_DELETION_API = 'false'
        }
        foreach ($key in $case.Changes.Keys) { $config[$key] = $case.Changes[$key] }
        $config | ConvertTo-Json | Set-Content -LiteralPath $temporaryConfig -Encoding UTF8
        $accepted = $false
        try {
            $null = & $buildScript -ConfigFile $temporaryConfig -BuildName 1.0.0 -BuildNumber 2 -ValidateOnly
            $accepted = $true
        } catch {
            # The expected rejection must come from config validation, not command loading.
            if ($_.InvocationInfo.ScriptName -ne $buildScript) { throw }
        }
        if ($accepted -ne $case.Accept) { throw "Unexpected result: $($case.Name)" }
        Write-Output "PASS: $($case.Name)"
    }
} finally {
    if (Test-Path -LiteralPath $temporaryConfig) { Remove-Item -LiteralPath $temporaryConfig }
}

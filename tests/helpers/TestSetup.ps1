# Dot-source in BeforeAll; pair with AfterAll { Remove-PortcullisTestEnvironment }.
# Puts tests/stubs first on PSModulePath (so Portcullis's RequiredModules, Pode and Pode.Web, resolve
# to the stubs), imports the WSUS and UpdateServices stubs and the Portcullis module, and defines
# helpers for a test configuration in TestDrive.

$script:repoRoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..')
$stubRoot = Join-Path -Path $script:repoRoot -ChildPath 'tests\stubs'
$script:testModuleNames = 'Portcullis', 'Pode.Web', 'Pode', 'WSUS', 'UpdateServices'

if (-not $env:PORTCULLIS_TEST_ORIGINAL_PSMODULEPATH) {
    $env:PORTCULLIS_TEST_ORIGINAL_PSMODULEPATH = $env:PSModulePath
}
$env:PSModulePath = $stubRoot + [IO.Path]::PathSeparator + $env:PORTCULLIS_TEST_ORIGINAL_PSMODULEPATH

Get-Module -Name $script:testModuleNames | Remove-Module -Force
Import-Module -Name (Join-Path -Path $stubRoot -ChildPath 'WSUS\WSUS.psm1') -Global -Force
Import-Module -Name (Join-Path -Path $stubRoot -ChildPath 'UpdateServices\UpdateServices.psm1') -Global -Force
Import-Module -Name (Join-Path -Path $script:repoRoot -ChildPath 'src\Portcullis\Portcullis.psd1') -Global -Force

function New-TestConfig {
    <#
    .SYNOPSIS
        Writes a configuration file to TestDrive and returns Get-PortcullisConfig's result for it.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Test helper writing to TestDrive; ShouldProcess adds nothing.')]
    param (
        # Keys to set or override.
        [hashtable] $Value = @{}
    )

    $settings = @{
        UpstreamServer = 'wsus01.test.local'
        ReplicaServer  = 'wsus02.test.local'
        AuditLogPath   = Join-Path -Path $TestDrive -ChildPath "audit-$([guid]::NewGuid())\audit.log"
    }
    foreach ($key in $Value.Keys) { $settings[$key] = $Value[$key] }

    $path = Join-Path -Path $TestDrive -ChildPath "config-$([guid]::NewGuid()).psd1"
    $lines = foreach ($key in $settings.Keys) { "    $key = '$($settings[$key])'" }
    Set-Content -Path $path -Value ("@{`n" + ($lines -join "`n") + "`n}") -Encoding UTF8
    Get-PortcullisConfig -Path $path
}

function Get-TestAuditEntry {
    <#
    .SYNOPSIS
        The audit lines written so far, parsed.
    #>
    param (
        # Configuration whose audit log to read.
        [object] $Config
    )

    if (-not (Test-Path -LiteralPath $Config.AuditLogPath)) { return }
    Get-Content -LiteralPath $Config.AuditLogPath | ForEach-Object { $_ | ConvertFrom-Json }
}

function Remove-PortcullisTestEnvironment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Test teardown helper; ShouldProcess adds nothing.')]
    param ()
    Get-Module -Name $script:testModuleNames | Remove-Module -Force
    if ($env:PORTCULLIS_TEST_ORIGINAL_PSMODULEPATH) {
        $env:PSModulePath = $env:PORTCULLIS_TEST_ORIGINAL_PSMODULEPATH
        Remove-Item -Path Env:\PORTCULLIS_TEST_ORIGINAL_PSMODULEPATH
    }
}

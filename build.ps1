<#
.SYNOPSIS
    Build script for Portcullis: analyse, test and check a release. CI only calls this script.

.DESCRIPTION
    Tasks:
      Analyze  PSScriptAnalyzer over src, tests, server.ps1, dev and this script, using PSScriptAnalyzerSettings.psd1.
               Fails on Error or Warning.
      Test     Pester 5 over tests/. Writes artifacts/testResults.xml (NUnit) and
               artifacts/coverage.xml (JaCoCo). Coverage is reported only; there is no threshold.
      All      Analyze, then Test.
      Release  Checks a release is ready (manifest version equals the vX.Y.Z tag on HEAD, CHANGELOG has
               a section for it, working tree clean) and stages the deployable site (server.ps1, server.psd1,
               web.config, config/portcullis.example.psd1, public, src/Portcullis) to artifacts/stage/Portcullis.
               It never deploys; deployment is manual (docs/hosting-iis.md).

    Pester and PSScriptAnalyzer versions are pinned below and installed for the current user if missing.
    Exits non-zero on failure.

.EXAMPLE
    ./build.ps1 -Task All
#>
#Requires -Version 5.1
[CmdletBinding()]
param (
    [ValidateSet('Analyze', 'Test', 'All', 'Release')]
    [string] $Task = 'All'
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$PesterVersion = '5.7.1'
$ScriptAnalyzerVersion = '1.24.0'

$repoRoot = $PSScriptRoot
$modulePath = Join-Path $repoRoot 'src\Portcullis'
$manifestPath = Join-Path $modulePath 'Portcullis.psd1'
$artifacts = Join-Path $repoRoot 'artifacts'

function Import-PinnedModule {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseCompatibleCmdlets', '',
        Justification = 'Install-Module is PowerShellGet, present on every node and runner but missing from the compatibility profile.')]
    param ([string] $Name, [string] $Version)

    if (-not (Get-Module -ListAvailable -Name $Name | Where-Object { $_.Version -eq [version] $Version })) {
        Write-Information "Installing $Name $Version for the current user"
        Install-Module -Name $Name -RequiredVersion $Version -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber
    }
    if (Get-Module -Name $Name | Where-Object { $_.Version -eq [version] $Version }) { return }
    Get-Module -Name $Name | Remove-Module -Force
    Import-Module -Name $Name -RequiredVersion $Version
}

function Invoke-Analyze {
    # Load the pinned Pester first: analysing test files can otherwise autoload the newest installed
    # Pester, whose assembly then blocks loading the pinned one in the same session.
    Import-PinnedModule -Name Pester -Version $PesterVersion
    Import-PinnedModule -Name PSScriptAnalyzer -Version $ScriptAnalyzerVersion

    $settings = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'
    $targets = @(
        (Join-Path $repoRoot 'src'),
        (Join-Path $repoRoot 'tests'),
        (Join-Path $repoRoot 'dev'),
        (Join-Path $repoRoot 'server.ps1'),
        (Join-Path $repoRoot 'build.ps1')
    )
    # tests/stubs and dev/modules are excluded as locations: they imitate the WSUS and UpdateServices
    # modules, with unused parameters, throwing bodies or canned data on purpose.
    $findings = foreach ($target in $targets) {
        Invoke-ScriptAnalyzer -Path $target -Recurse -Settings $settings |
            Where-Object { $_.ScriptPath -notmatch '[\\/](tests[\\/]stubs|dev[\\/]modules)[\\/]' }
    }
    if ($findings) {
        Write-Information ($findings | Format-Table -AutoSize RuleName, Severity, ScriptName, Line, Message | Out-String -Width 200)
        throw "PSScriptAnalyzer reported $(@($findings).Count) finding(s)."
    }
    Write-Information 'PSScriptAnalyzer: clean'
}

function Invoke-Test {
    Import-PinnedModule -Name Pester -Version $PesterVersion
    $null = New-Item -ItemType Directory -Path $artifacts -Force

    $config = New-PesterConfiguration
    $config.Run.Path = Join-Path $repoRoot 'tests'
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputFormat = 'NUnitXml'
    $config.TestResult.OutputPath = Join-Path $artifacts 'testResults.xml'
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.Path = Join-Path $modulePath '*'
    $config.CodeCoverage.RecursePaths = $true
    $config.CodeCoverage.OutputFormat = 'JaCoCo'
    $config.CodeCoverage.OutputPath = Join-Path $artifacts 'coverage.xml'

    $result = Invoke-Pester -Configuration $config
    if ($result.FailedCount -gt 0 -or $result.FailedBlocksCount -gt 0 -or $result.FailedContainersCount -gt 0) {
        throw "Pester: $($result.FailedCount) test(s) failed."
    }
    Write-Information ('Pester: {0} passed. Coverage {1:N1}% (report only).' -f $result.PassedCount, $result.CodeCoverage.CoveragePercent)
}

function Invoke-Release {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseCompatibleCmdlets', '',
        Justification = 'Update-ModuleManifest is PowerShellGet, missing from the compatibility profile.')]
    param ()

    $version = (Import-PowerShellDataFile -Path $manifestPath).ModuleVersion
    $tag = "v$version"

    $tagsAtHead = @(git -C $repoRoot tag --points-at HEAD)
    if ($tagsAtHead -notcontains $tag) {
        throw "Manifest version is $version but HEAD is not tagged $tag (tags at HEAD: $($tagsAtHead -join ', '))."
    }

    $changelog = Get-Content -Path (Join-Path $repoRoot 'CHANGELOG.md') -Raw
    $pattern = '(?ms)^## \[' + [regex]::Escape($version) + '\][^\r\n]*\r?\n(?<body>.*?)(?=^## \[|\z)'
    $section = [regex]::Match($changelog, $pattern)
    if (-not $section.Success) {
        throw "CHANGELOG.md has no '## [$version]' section."
    }

    if (git -C $repoRoot status --porcelain) {
        throw 'The working tree is not clean.'
    }

    $stage = Join-Path $artifacts 'stage\Portcullis'
    if (Test-Path -Path $stage) { Remove-Item -Path $stage -Recurse -Force }
    $null = New-Item -ItemType Directory -Path (Join-Path $stage 'src\Portcullis') -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $stage 'config') -Force
    foreach ($file in 'server.ps1', 'server.psd1', 'web.config') {
        Copy-Item -Path (Join-Path $repoRoot $file) -Destination $stage
    }
    Copy-Item -Path (Join-Path $repoRoot 'config\portcullis.example.psd1') -Destination (Join-Path $stage 'config')
    Copy-Item -Path (Join-Path $modulePath '*') -Destination (Join-Path $stage 'src\Portcullis') -Recurse
    Copy-Item -Path (Join-Path $repoRoot 'public') -Destination $stage -Recurse

    $notes = $section.Groups['body'].Value.Trim() + "`n`nFull changelog: https://github.com/camusicjunkie/Portcullis/blob/$tag/CHANGELOG.md"
    Update-ModuleManifest -Path (Join-Path $stage 'src\Portcullis\Portcullis.psd1') -ReleaseNotes $notes
    Write-Information "Staged $tag at $stage. Deploy it by hand (docs/hosting-iis.md)."
}

switch ($Task) {
    'Analyze' { Invoke-Analyze }
    'Test' { Invoke-Test }
    'All' { Invoke-Analyze; Invoke-Test }
    'Release' { Invoke-Release }
}

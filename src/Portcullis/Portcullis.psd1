@{
    RootModule           = 'Portcullis.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '4b7f2d9e-61c3-4a8e-9f0b-2c5d8e1a7f43'
    Author               = 'John Steele'
    CompanyName          = 'Unknown'
    Copyright            = '(c) John Steele. All rights reserved.'
    Description          = 'Logic behind the Portcullis WSUS admin portal: node status, ring gate previews, approvals, declines and syncs, with an audit trail. The Pode web server lives in server.ps1.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop')

    # The web server's modules, pinned to the exact versions the portal is tested against. Pode.Web
    # 1.0.0 is a prerelease (1.0.0-preview3): a manifest cannot name the prerelease label, so this
    # entry matches any 1.0.0 build. Install it with -AllowPrerelease. Tests load stand-ins from
    # tests/stubs so they need neither installed.
    # The WSUS module is loaded by name at run time and stays out of this list: it only exists in the
    # internal gallery.
    RequiredModules      = @(
        @{ ModuleName = 'Pode'; RequiredVersion = '2.14.1'; GUID = 'e3ea217c-fc3d-406b-95d5-4304ab06c6af' }
        @{ ModuleName = 'Pode.Web'; RequiredVersion = '1.0.0'; GUID = '5c6cae5a-8e62-48a4-c2e5-7511ffe2d439' }
    )

    # Hand-listed: must match the files in Public/ (checked by tests/Module.Tests.ps1).
    FunctionsToExport    = @(
        'Assert-PortcullisAuditSource'
        'Find-PortcullisUpdate'
        'Format-PortcullisInstallTime'
        'Get-PortcullisAuditLog'
        'Get-PortcullisConfig'
        'Get-PortcullisInstallSchedule'
        'Get-PortcullisNextInstall'
        'Get-PortcullisNodeStatus'
        'Get-PortcullisPatchCalendar'
        'Get-PortcullisRingPreview'
        'Invoke-PortcullisDecline'
        'Invoke-PortcullisRingApproval'
        'Invoke-PortcullisSync'
        'New-PortcullisPreview'
        'Resolve-PortcullisUser'
        'Select-PortcullisPendingRow'
        'Test-PortcullisRequestOrigin'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            Tags         = @('WSUS', 'Pode', 'Portal')
            ProjectUri   = 'https://github.com/camusicjunkie/Portcullis'
            ReleaseNotes = 'See CHANGELOG.md in the project repository.'
        }
    }
}

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

    # The WSUS module is loaded by name at run time (it lives in the internal gallery), so it is not a
    # RequiredModules entry: that would make every test run need the real module installed.

    # Hand-listed: must match the files in Public/ (checked by tests/Module.Tests.ps1).
    FunctionsToExport    = @(
        'Find-PortcullisUpdate'
        'Get-PortcullisAuditLog'
        'Get-PortcullisConfig'
        'Get-PortcullisNodeStatus'
        'Get-PortcullisRingPreview'
        'Invoke-PortcullisDecline'
        'Invoke-PortcullisRingApproval'
        'Invoke-PortcullisSync'
        'New-PortcullisPreview'
        'Resolve-PortcullisUser'
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

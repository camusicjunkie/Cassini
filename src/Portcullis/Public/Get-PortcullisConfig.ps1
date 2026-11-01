function Get-PortcullisConfig {
    <#
    .SYNOPSIS
        Reads and checks the portal's configuration file.
    .DESCRIPTION
        The file is a PowerShell data file (.psd1); config/portcullis.example.psd1 lists every key.
        Missing optional keys take their defaults. An unknown key, a missing required key or a bad
        value throws, so the server refuses to start rather than run half-configured.

        Required: UpstreamServer. Everything else has a default:
          ReplicaServer         ''                    (no replica shown)
          Port                  8531
          AdminGroup            'res.srv.wsus.admin'  (AD group allowed to use the portal)
          Authentication        'IIS'                 ('None' only for local development)
          ListenPort            8080                  (ignored under IIS, which assigns the port)
          AuditLogPath          'C:\ProgramData\Portcullis\audit.log'
          PreviewMaxAgeMinutes  15                    (how long a preview can be confirmed)
          Title                 'Portcullis'
    .EXAMPLE
        $config = Get-PortcullisConfig -Path .\config\portcullis.psd1
    .OUTPUTS
        Portcullis.Config
    #>
    [CmdletBinding()]
    [OutputType('Portcullis.Config')]
    param (
        # Path to the .psd1 configuration file.
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Configuration file '$Path' not found. Copy config/portcullis.example.psd1 and edit it."
    }
    $data = Import-PowerShellDataFile -LiteralPath $Path

    $defaults = [ordered]@{
        UpstreamServer       = $null
        ReplicaServer        = ''
        Port                 = 8531
        AdminGroup           = 'res.srv.wsus.admin'
        Authentication       = 'IIS'
        ListenPort           = 8080
        AuditLogPath         = 'C:\ProgramData\Portcullis\audit.log'
        PreviewMaxAgeMinutes = 15
        Title                = 'Portcullis'
    }

    $unknown = @($data.Keys | Where-Object { $_ -notin $defaults.Keys })
    if ($unknown) {
        throw "Unknown configuration key(s) in '$Path': $($unknown -join ', '). Valid keys: $($defaults.Keys -join ', ')."
    }

    $config = [ordered]@{ PSTypeName = 'Portcullis.Config' }
    foreach ($key in $defaults.Keys) {
        $config[$key] = if ($data.ContainsKey($key)) { $data[$key] } else { $defaults[$key] }
    }

    if (-not $config.UpstreamServer) {
        throw "UpstreamServer is required in '$Path'."
    }
    if ($config.ReplicaServer -and $config.ReplicaServer -eq $config.UpstreamServer) {
        throw 'ReplicaServer must differ from UpstreamServer.'
    }
    if ($config.Authentication -notin 'IIS', 'None') {
        throw "Authentication must be 'IIS' or 'None', not '$($config.Authentication)'."
    }
    if ($config.Authentication -eq 'IIS' -and -not $config.AdminGroup) {
        throw 'AdminGroup is required when Authentication is IIS.'
    }
    foreach ($key in 'Port', 'ListenPort') {
        if (($config[$key] -as [int]) -notin 1..65535) {
            throw "$key must be a port number (1-65535), not '$($config[$key])'."
        }
        $config[$key] = [int] $config[$key]
    }
    if (($config.PreviewMaxAgeMinutes -as [int]) -notin 1..120) {
        throw "PreviewMaxAgeMinutes must be 1 to 120, not '$($config.PreviewMaxAgeMinutes)'."
    }
    $config.PreviewMaxAgeMinutes = [int] $config.PreviewMaxAgeMinutes

    [PSCustomObject] $config
}

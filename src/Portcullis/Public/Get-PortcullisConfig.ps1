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
          SessionMinutes        15                    (sign-in session idle time-out, 5 to 480)
          AuditEventLog         'Required' under IIS, 'Optional' with Authentication None
                                (Required: the server refuses to start without the 'Portcullis'
                                event source, so every change also reaches the Event Log)
          Title                 'Portcullis'
          Schedule              When each ring installs (WSUS README, section 7). One entry per
                                ring (Pilot, Workstations, Servers), each with:
                                  Gpo             GPO to read the schedule from ('' to use the
                                                  values below only); default 'WSUS - <ring>'
                                  Day             Sunday..Saturday, or Everyday
                                  Hour            0 to 23 (client local time)
                                  DetectionHours  1 to 48: how long clients can take to see an
                                                  approval (DetectionFrequency); default 22
                                A ring left out keeps its default; Pilot Thursday, Workstations
                                Wednesday, Servers Thursday, all 19:00.
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
        SessionMinutes       = 15
        AuditEventLog        = $null
        Title                = 'Portcullis'
        Schedule             = $null
    }
    $defaultSchedule = [ordered]@{
        Pilot        = @{ Gpo = 'WSUS - Pilot'; Day = 'Thursday'; Hour = 19; DetectionHours = 22 }
        Workstations = @{ Gpo = 'WSUS - Workstations'; Day = 'Wednesday'; Hour = 19; DetectionHours = 22 }
        Servers      = @{ Gpo = 'WSUS - Servers'; Day = 'Thursday'; Hour = 19; DetectionHours = 22 }
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
    if (($config.SessionMinutes -as [int]) -notin 5..480) {
        throw "SessionMinutes must be 5 to 480, not '$($config.SessionMinutes)'."
    }
    $config.SessionMinutes = [int] $config.SessionMinutes

    if (-not $config.AuditEventLog) {
        $config.AuditEventLog = if ($config.Authentication -eq 'IIS') { 'Required' } else { 'Optional' }
    }
    if ($config.AuditEventLog -notin 'Required', 'Optional') {
        throw "AuditEventLog must be 'Required' or 'Optional', not '$($config.AuditEventLog)'."
    }

    $given = if ($null -eq $config.Schedule) { @{} } else { $config.Schedule }
    if ($given -isnot [hashtable]) {
        throw 'Schedule must be a hashtable keyed by ring (Pilot, Workstations, Servers).'
    }
    $unknownRing = @($given.Keys | Where-Object { $_ -notin $defaultSchedule.Keys })
    if ($unknownRing) {
        throw "Unknown ring(s) in Schedule: $($unknownRing -join ', '). Valid rings: $($defaultSchedule.Keys -join ', ')."
    }
    $days = [enum]::GetNames([DayOfWeek]) + 'Everyday'
    $schedule = [ordered]@{}
    foreach ($ring in $defaultSchedule.Keys) {
        $entry = @{} + $defaultSchedule[$ring]
        if ($given.ContainsKey($ring)) {
            if ($given[$ring] -isnot [hashtable]) {
                throw "Schedule.$ring must be a hashtable (Gpo, Day, Hour, DetectionHours)."
            }
            $unknownSetting = @($given[$ring].Keys | Where-Object { $_ -notin $entry.Keys })
            if ($unknownSetting) {
                throw "Unknown setting(s) in Schedule.${ring}: $($unknownSetting -join ', '). Valid: Gpo, Day, Hour, DetectionHours."
            }
            foreach ($setting in $given[$ring].Keys) { $entry[$setting] = $given[$ring][$setting] }
        }
        if ($entry.Day -notin $days) {
            throw "Schedule.$ring.Day must be Sunday to Saturday or Everyday, not '$($entry.Day)'."
        }
        $entry.Day = $days | Where-Object { $_ -eq $entry.Day }
        if (($entry.Hour -as [int]) -notin 0..23) {
            throw "Schedule.$ring.Hour must be 0 to 23, not '$($entry.Hour)'."
        }
        if (($entry.DetectionHours -as [int]) -notin 1..48) {
            throw "Schedule.$ring.DetectionHours must be 1 to 48, not '$($entry.DetectionHours)'."
        }
        $entry.Hour = [int] $entry.Hour
        $entry.DetectionHours = [int] $entry.DetectionHours
        $entry.Gpo = [string] $entry.Gpo
        $schedule[$ring] = $entry
    }
    $config.Schedule = $schedule

    [PSCustomObject] $config
}

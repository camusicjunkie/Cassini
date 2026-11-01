function Get-CassiniInstallSchedule {
    <#
    .SYNOPSIS
        When each ring installs: from its GPO where it can be read, otherwise from the configuration.
    .DESCRIPTION
        Approvals decide what a ring installs; the client GPO decides when (WSUS README, section 7).
        For each ring in the configuration's Schedule, reads ScheduledInstallDay, ScheduledInstallTime,
        the week settings and DetectionFrequency from its Gpo. If Gpo is empty the configured values
        are used as they are; if the GPO cannot be read they are used with a Warning saying why.

        A GPO that installs only in some weeks of the month also gets a Warning: Patch Tuesday moves
        between the 8th and the 14th, so "the second Thursday" is not always the Thursday after it.
    .EXAMPLE
        Get-CassiniInstallSchedule -Config $config | Format-Table
    .OUTPUTS
        Cassini.InstallSchedule
    #>
    [CmdletBinding()]
    [OutputType('Cassini.InstallSchedule')]
    param (
        # Portal configuration from Get-CassiniConfig.
        [Parameter(Mandatory)]
        [object] $Config
    )

    $dayNames = @('Everyday') + [enum]::GetNames([DayOfWeek])

    foreach ($ring in $Config.Schedule.Keys) {
        $entry = $Config.Schedule[$ring]
        $row = [ordered]@{
            PSTypeName     = 'Cassini.InstallSchedule'
            Ring           = $ring
            Day            = $entry.Day
            Hour           = $entry.Hour
            Weeks          = @()
            DetectionHours = $entry.DetectionHours
            Source         = 'Configuration'
            Warning        = ''
        }

        if ($entry.Gpo) {
            try {
                $gpo = Get-CassiniGpoInstallSetting -Name $entry.Gpo
                if ($gpo.Day -notin 0..7 -or $gpo.Hour -notin 0..23) {
                    throw "unexpected values (day $($gpo.Day), hour $($gpo.Hour))"
                }
                # GPO days: 0 = every day, 1 = Sunday ... 7 = Saturday.
                $row.Day = $dayNames[$gpo.Day]
                $row.Hour = $gpo.Hour
                if (-not $gpo.EveryWeek) {
                    $row.Weeks = @($gpo.Weeks)
                    $row.Warning = "GPO '$($entry.Gpo)' installs only in week(s) $($gpo.Weeks -join ', ') of the month, which does not always follow Patch Tuesday. Set ScheduledInstallEveryWeek = 1."
                }
                if ($gpo.DetectionHours -in 1..48) {
                    $row.DetectionHours = $gpo.DetectionHours
                }
                $row.Source = "GPO '$($entry.Gpo)'"
            }
            catch {
                $row.Warning = "Could not read GPO '$($entry.Gpo)' ($($_.Exception.Message -replace '\.$', '')); using the configured $($entry.Day) $($entry.Hour):00."
            }
        }

        [PSCustomObject] $row
    }
}

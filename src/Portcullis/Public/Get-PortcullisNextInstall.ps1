function Get-PortcullisNextInstall {
    <#
    .SYNOPSIS
        The first install window in which a ring installs an update approved at a given time.
    .DESCRIPTION
        A client only installs what it has detected, and it scans every DetectionHours. An approval
        is therefore safe for the first window that starts at least DetectionHours after it. That
        window is returned, with the latest approval time that still makes it (Deadline).

        Times are the GPO's clock: client local time.
    .EXAMPLE
        Get-PortcullisNextInstall -Schedule $schedule -Ring Workstations -After (Get-Date)
    .OUTPUTS
        Portcullis.NextInstall
    #>
    [CmdletBinding()]
    [OutputType('Portcullis.NextInstall')]
    param (
        # Rows from Get-PortcullisInstallSchedule.
        [Parameter(Mandatory)]
        [object[]] $Schedule,

        # Ring to project, e.g. Workstations.
        [Parameter(Mandatory)]
        [string] $Ring,

        # When the approval is made. Default now.
        [datetime] $After = (Get-Date)
    )

    $row = $Schedule | Where-Object { $_.Ring -eq $Ring } | Select-Object -First 1
    if (-not $row) {
        throw "No schedule for ring '$Ring'."
    }

    $earliest = $After.AddHours($row.DetectionHours)
    $window = $earliest.Date.AddHours($row.Hour)
    if ($window -lt $earliest) {
        $window = $window.AddDays(1)
    }

    # At most a few months ahead; a schedule that never matches would be a configuration error.
    for ($i = 0; $i -lt 130; $i++) {
        $dayMatches = $row.Day -eq 'Everyday' -or $window.DayOfWeek.ToString() -eq $row.Day
        $weekOfMonth = [math]::Ceiling($window.Day / 7)
        $weekMatches = @($row.Weeks).Count -eq 0 -or $weekOfMonth -in $row.Weeks
        if ($dayMatches -and $weekMatches) {
            return [PSCustomObject] @{
                PSTypeName = 'Portcullis.NextInstall'
                Ring       = $Ring
                Start      = $window
                Deadline   = $window.AddHours(-$row.DetectionHours)
            }
        }
        $window = $window.AddDays(1)
    }
    throw "Ring '$Ring' has no install window in the next 130 days."
}

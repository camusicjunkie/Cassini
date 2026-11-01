function Format-PortcullisInstallTime {
    <#
    .SYNOPSIS
        One sentence saying when the promoted rings install an approval made at a given time.
    .DESCRIPTION
        For the Promote rings page: shown with the preview ("if approved now") and kept with the last
        approval. Every ring other than Pilot is a promoted ring. Times are client local time, which
        the sentence says, because the GPO sets the clock on the client, not on the portal.
    .EXAMPLE
        Format-PortcullisInstallTime -Schedule $schedule -After (Get-Date)
        Installs start Wed 12 Nov 19:00 (Workstations) and Thu 13 Nov 19:00 (Servers), client local time.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        # Rows from Get-PortcullisInstallSchedule.
        [Parameter(Mandatory)]
        [object[]] $Schedule,

        # When the approval is (or was) made.
        [datetime] $After = (Get-Date)
    )

    $culture = [Globalization.CultureInfo]::InvariantCulture
    $parts = @(foreach ($row in ($Schedule | Where-Object { $_.Ring -ne 'Pilot' })) {
            $next = Get-PortcullisNextInstall -Schedule $Schedule -Ring $row.Ring -After $After
            '{0} ({1})' -f $next.Start.ToString('ddd d MMM HH:mm', $culture), $row.Ring
        })
    if (-not $parts) {
        return ''
    }

    $list = if ($parts.Count -eq 1) { $parts[0] } else { ($parts[0..($parts.Count - 2)] -join ', ') + ' and ' + $parts[-1] }
    "Installs start $list, client local time."
}

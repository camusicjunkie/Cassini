function Get-CassiniRingPreview {
    <#
    .SYNOPSIS
        Runs the Approve-WsusRing gate against the upstream without approving anything.
    .DESCRIPTION
        Calls WSUS\Approve-WsusRing -WhatIf with the given gate settings and returns the gate table
        plus a preview record (New-CassiniPreview) that Invoke-CassiniRingApproval needs to
        confirm exactly these settings.

        Rows are flattened for the web table: Reason is one sentence, and OnConfirm says whether the
        update would be approved (for the target rings that don't have it yet) or held. Approve-WsusRing's
        "held" warning is not repeated; the Summary counts them.
    .EXAMPLE
        $result = Get-CassiniRingPreview -Config $config
        $result.Rows | Format-Table
    .OUTPUTS
        Cassini.RingPreview
    #>
    [CmdletBinding()]
    [OutputType('Cassini.RingPreview')]
    param (
        # Portal configuration from Get-CassiniConfig.
        [Parameter(Mandatory)]
        [PSTypeName('Cassini.Config')]
        [object] $Config,

        # Days an update must have been approved for Pilot. Approve-WsusRing's default is 5.
        [ValidateRange(0, 60)]
        [int] $MinimumSoakDays = 5,

        # Percent of the Pilot computers that need it that must have it installed. Default 90.
        [ValidateRange(0, 100)]
        [int] $MinimumInstalledPercent = 90,

        # Approve updates that fail the gate (out-of-band updates only).
        [switch] $Force
    )

    $parameters = @{
        MinimumSoakDays         = $MinimumSoakDays
        MinimumInstalledPercent = $MinimumInstalledPercent
        Force                   = [bool] $Force
    }

    $gate = WSUS\Approve-WsusRing @parameters -WsusServer $Config.UpstreamServer -Port $Config.Port -WhatIf -WarningAction SilentlyContinue

    $rows = @(foreach ($row in $gate) {
            [PSCustomObject] @{
                PSTypeName = 'Cassini.RingRow'
                Kb         = Format-CassiniKb -Value $row.Kb
                Update     = $row.Update
                Gate       = $row.Gate
                Installed  = '{0} of {1} ({2}%)' -f $row.Installed, $row.Needed, $row.Percent
                Failed     = $row.Failed
                Reason     = ConvertTo-CassiniSentence -Text (@($row.Reason) -join '; ')
                OnConfirm  = if ($row.Gate -eq 'Held') { 'Hold' } else { 'Approve' }
            }
        })

    $held = @($rows | Where-Object Gate -eq 'Held').Count
    [PSCustomObject] @{
        PSTypeName = 'Cassini.RingPreview'
        Rows       = $rows
        Summary    = [PSCustomObject] @{
            Candidates = $rows.Count
            Approvable = $rows.Count - $held
            Held       = $held
            Forced     = @($rows | Where-Object Gate -eq 'Forced').Count
        }
        Preview    = New-CassiniPreview -Kind Ring -Parameters $parameters
    }
}

function Get-PortcullisNodeStatus {
    <#
    .SYNOPSIS
        One display row per configured WSUS node, for the portal's status table.
    .DESCRIPTION
        Calls WSUS\Get-WsusNodeStatus for the upstream and (if configured) the replica. A node that
        cannot be reached still gets a row, with Reachable = $false and the error, so the table always
        shows both nodes.

        Like Get-WsusNodeStatus, it gives facts, not a health verdict. The one exception is Note: it
        flags a node whose reported role differs from its configured one (after a promotion, update
        the configuration), and a replica whose counts differ from the upstream's (expected for a few
        minutes after an upstream sync or approval).

        Content disk and log facts are $null for a remote node, so they are left out of the row.
    .EXAMPLE
        Get-PortcullisNodeStatus -Config $config | Format-Table
    .OUTPUTS
        Portcullis.NodeRow
    #>
    [CmdletBinding()]
    [OutputType('Portcullis.NodeRow')]
    param (
        # Portal configuration from Get-PortcullisConfig.
        [Parameter(Mandatory)]
        [PSTypeName('Portcullis.Config')]
        [object] $Config
    )

    $nodes = Get-PortcullisNode -Config $Config
    $rows = foreach ($node in $nodes) {
        $nodeError = $null
        $status = WSUS\Get-WsusNodeStatus -WsusServer $node.Server -Port $Config.Port -ErrorVariable nodeError -ErrorAction SilentlyContinue

        $row = [ordered]@{
            PSTypeName        = 'Portcullis.NodeRow'
            Node              = $node.Name
            Server            = $node.Server
            Reachable         = [bool] $status
            Role              = $null
            Sync              = $null
            LastSync          = $null
            LastSyncResult    = $null
            Updates           = $null
            Approved          = $null
            Declined          = $null
            DownloadPendingMB = $null
            DownloadFailed    = $null
            Note              = $null
        }

        if (-not $status) {
            $row.Note = if ($nodeError) { "Unreachable: $($nodeError[0].Exception.Message)" } else { 'Unreachable' }
            [PSCustomObject] $row
            continue
        }

        $row.Role = $status.Role
        $row.Sync = if ($status.SyncStatus -eq 'Running') {
            '{0} ({1} of {2})' -f $status.SyncPhase, $status.SyncProcessedItems, $status.SyncTotalItems
        }
        else {
            'Idle'
        }
        $row.LastSync = Format-PortcullisTime -Value $status.LastSyncTime
        $row.LastSyncResult = if ($status.LastSyncError) { "$($status.LastSyncResult): $($status.LastSyncError)" } else { $status.LastSyncResult }
        $row.Updates = $status.UpdateCount
        $row.Approved = $status.ApprovedUpdateCount
        $row.Declined = $status.DeclinedUpdateCount
        $row.DownloadPendingMB = $status.DownloadPendingMB
        $row.DownloadFailed = $status.DownloadFailedCount

        if ($status.Role -ne $node.Role) {
            $row.Note = "Configured as $($node.Role) but reports $($status.Role). Update the portal configuration after a promotion."
        }
        [PSCustomObject] $row
    }

    $upstream = $rows | Where-Object { $_.Node -eq 'Upstream' -and $_.Reachable }
    foreach ($row in $rows) {
        if ($row.Node -ne 'Replica' -or -not $row.Reachable -or -not $upstream -or $row.Note) {
            $row
            continue
        }
        $behind = foreach ($key in 'Updates', 'Approved', 'Declined') {
            if ($row.$key -ne $upstream.$key) { '{0} {1} vs {2}' -f $key, $row.$key, $upstream.$key }
        }
        if ($behind) {
            $row.Note = "Differs from upstream ($($behind -join ', ')). Normal for a few minutes after an upstream sync or approval."
        }
        $row
    }
}

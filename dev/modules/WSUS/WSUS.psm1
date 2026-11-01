# Fake WSUS module for running the portal without WSUS (dev/Start-DevServer.ps1).
# Same function names and parameters the portal uses, canned data, nothing real. Never deploy it.

# Ring approvals are remembered in a file, not in the module: Pode runs requests in several
# runspaces, each with its own copy of this module. Start-DevServer.ps1 sets the path and clears the
# file on every start. Without it (the variable unset) every preview starts from scratch.
function Get-FakeRingApproval {
    if (-not $env:PORTCULLIS_DEV_STATE -or -not (Test-Path -LiteralPath $env:PORTCULLIS_DEV_STATE)) {
        return
    }
    Get-Content -LiteralPath $env:PORTCULLIS_DEV_STATE
}

function Add-FakeRingApproval {
    param ([string] $Kb)

    if ($env:PORTCULLIS_DEV_STATE) {
        Add-Content -LiteralPath $env:PORTCULLIS_DEV_STATE -Value $Kb
    }
}

function Get-WsusNodeStatus {
    [CmdletBinding()]
    param ([string[]] $WsusServer, [int] $Port = 8531)

    foreach ($server in $WsusServer) {
        if ($server -match 'offline') {
            Write-Error -Message "Cannot connect to $server on port $Port." -ErrorId 'WsusNodeUnreachable'
            continue
        }
        $isReplica = $server -match '02'
        [PSCustomObject] @{
            PSTypeName          = 'WSUS.NodeStatus'
            Server              = $server
            Role                = if ($isReplica) { 'Replica' } else { 'Upstream' }
            LastSyncTime        = (Get-Date).Date.AddHours(2)
            LastSyncResult      = 'Succeeded'
            LastSyncError       = $null
            SyncStatus          = 'NotProcessing'
            SyncPhase           = $null
            SyncProcessedItems  = $null
            SyncTotalItems      = $null
            UpdateCount         = 4210
            ApprovedUpdateCount = 311
            DeclinedUpdateCount = 3120
            DownloadPendingMB   = 0
            DownloadFailedCount = 0
        }
    }
}

function Approve-WsusRing {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [int] $MinimumSoakDays = 5,
        [int] $MinimumInstalledPercent = 90,
        [switch] $Force,
        [string] $WsusServer,
        [int] $Port = 8531
    )

    $candidates = @(
        @{ Update = '2026-10 Cumulative Update for Windows 11 Version 24H2 for x64-based Systems'; Kb = '5066835'; Installed = 18; Needed = 19; Failed = 0; Age = 6 }
        @{ Update = '2026-10 Cumulative Update for Microsoft server operating system version 24H2'; Kb = '5066836'; Installed = 4; Needed = 4; Failed = 0; Age = 6 }
        @{ Update = '2026-10 Security Update for Microsoft Edge'; Kb = '5066901'; Installed = 12; Needed = 19; Failed = 1; Age = 6 }
        @{ Update = '2026-10 Servicing Stack Update for Windows Server 2022'; Kb = '5066840'; Installed = 3; Needed = 3; Failed = 0; Age = 2 }
    )
    $promoted = @(Get-FakeRingApproval)
    foreach ($c in $candidates) {
        # Like the real Approve-WsusRing: an update already approved for every ring is no candidate.
        if ($c.Kb -in $promoted) {
            continue
        }
        $percent = [int] [math]::Floor(100 * $c.Installed / $c.Needed)
        $reasons = @(
            if ($c.Age -lt $MinimumSoakDays) { 'approved for Pilot on {0:yyyy-MM-dd}, soak not finished' -f (Get-Date).AddDays(-$c.Age) }
            if ($percent -lt $MinimumInstalledPercent) { "only $percent% installed in Pilot" }
            if ($c.Failed -gt 0) { "$($c.Failed) failed in Pilot" }
        )
        $gate = if (-not $reasons) { 'Passed' } elseif ($Force) { 'Forced' } else { 'Held' }
        $approvedTo = @()
        if ($gate -ne 'Held' -and $PSCmdlet.ShouldProcess($c.Update, 'Approve')) {
            $approvedTo = 'Workstations', 'Servers'
            Add-FakeRingApproval -Kb $c.Kb
        }
        [PSCustomObject] @{
            PSTypeName = 'WSUS.RingApproval'
            Update     = $c.Update
            Kb         = $c.Kb
            Installed  = $c.Installed
            Needed     = $c.Needed
            Percent    = $percent
            Failed     = $c.Failed
            Gate       = $gate
            Reason     = $reasons
            ApprovedTo = $approvedTo
        }
    }
}

function Deny-WsusUpdate {
    [CmdletBinding(SupportsShouldProcess)]
    param ([string[]] $Kb, [string] $WsusServer, [int] $Port = 8531)

    foreach ($article in $Kb) {
        $number = $article -replace '^KB', ''
        foreach ($arch in 'x64', 'arm64') {
            $title = "2026-10 Security Update for Microsoft Edge ($arch)"
            # Stateless: every decline succeeds, in every runspace.
            $action = 'Declined'
            if ($action -eq 'Declined') {
                if (-not $PSCmdlet.ShouldProcess($title, 'Decline update')) { continue }
            }
            [PSCustomObject] @{
                PSTypeName = 'WSUS.DeclineResult'
                Kb         = "KB$number"
                Update     = $title
                Action     = $action
                NextStep   = 'Remove the update from machines that already installed it with DISM (README section 5).'
            }
        }
    }
}

function Start-WsusSync {
    [CmdletBinding(SupportsShouldProcess)]
    param ([string] $WsusServer, [int] $Port = 8531)

    if ($PSCmdlet.ShouldProcess($WsusServer, 'Start Full sync')) {
        [PSCustomObject] @{ PSTypeName = 'WSUS.SyncResult'; Server = $WsusServer; Mode = 'Full'; Started = Get-Date; Status = 'Started'; NextStep = 'Check the outcome with Get-WsusNodeStatus.' }
    }
}

Export-ModuleMember -Function Get-WsusNodeStatus, Approve-WsusRing, Deny-WsusUpdate, Start-WsusSync

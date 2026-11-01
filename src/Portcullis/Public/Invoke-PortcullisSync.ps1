function Invoke-PortcullisSync {
    <#
    .SYNOPSIS
        Starts a full sync on the upstream or the replica, without waiting for it.
    .DESCRIPTION
        Calls WSUS\Start-WsusSync for the configured node. The portal never waits: a full sync can run
        for hours, so watch it on the status page. If a sync is already running nothing new starts
        and Status is AlreadyRunning.

        No preview is needed: starting a sync changes no approval. Every run is audited.
    .EXAMPLE
        Invoke-PortcullisSync -Config $config -Node Replica -User 'CORP\jsteele'
    .OUTPUTS
        WSUS.SyncResult
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType('WSUS.SyncResult')]
    param (
        # Portal configuration from Get-PortcullisConfig.
        [Parameter(Mandatory)]
        [PSTypeName('Portcullis.Config')]
        [object] $Config,

        # Which configured node to sync.
        [Parameter(Mandatory)]
        [ValidateSet('Upstream', 'Replica')]
        [string] $Node,

        # The person confirming (Resolve-PortcullisUser).
        [Parameter(Mandatory)]
        [string] $User
    )

    $target = Get-PortcullisNode -Config $Config | Where-Object Name -eq $Node
    if (-not $target) {
        throw "No $Node is configured (set ReplicaServer in the portal configuration)."
    }

    if (-not $PSCmdlet.ShouldProcess($target.Server, 'Start full sync')) {
        return
    }

    $audit = @{
        Config = $Config
        User   = $User
        Action = 'StartSync'
        Server = $target.Server
    }

    try {
        $result = WSUS\Start-WsusSync -WsusServer $target.Server -Port $Config.Port -Confirm:$false -WarningAction SilentlyContinue
    }
    catch {
        Write-PortcullisAudit @audit -Outcome Failed -Detail @{ Error = $_.Exception.Message }
        throw
    }

    Write-PortcullisAudit @audit -Outcome Succeeded -Detail @{ Status = $result.Status }
    $result
}

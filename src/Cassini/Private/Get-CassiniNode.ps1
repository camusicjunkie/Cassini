function Get-CassiniNode {
    <#
    .SYNOPSIS
        The configured nodes: the upstream, then the replica if one is set.
    .DESCRIPTION
        Data only. Name is what the portal calls the node (and what Invoke-CassiniSync takes);
        Role is what the node should report through Get-WsusNodeStatus.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        # Portal configuration from Get-CassiniConfig.
        [Parameter(Mandatory)]
        [object] $Config
    )

    [PSCustomObject] @{ Name = 'Upstream'; Server = $Config.UpstreamServer; Role = 'Upstream' }
    if ($Config.ReplicaServer) {
        [PSCustomObject] @{ Name = 'Replica'; Server = $Config.ReplicaServer; Role = 'Replica' }
    }
}

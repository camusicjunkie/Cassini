# Stub of the WSUS module for tests: the functions the portal calls, with the parameters it passes.
# Every body throws so an unmocked call fails loudly. The fake with data for running the server
# locally is dev/modules/WSUS, not this.

function Get-WsusNodeStatus {
    [CmdletBinding()]
    param ([string[]] $WsusServer, [int] $Port)
    throw 'Stub Get-WsusNodeStatus called: mock it.'
}

function Approve-WsusRing {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [string] $From, [string[]] $To, [string[]] $Classification,
        [int] $MinimumSoakDays, [int] $MinimumInstalledPercent, [switch] $Force,
        [string] $WsusServer, [int] $Port
    )
    throw 'Stub Approve-WsusRing called: mock it.'
}

function Deny-WsusUpdate {
    [CmdletBinding(SupportsShouldProcess)]
    param ([string[]] $Kb, [string] $WsusServer, [int] $Port)
    throw 'Stub Deny-WsusUpdate called: mock it.'
}

function Start-WsusSync {
    [CmdletBinding(SupportsShouldProcess)]
    param ([string] $WsusServer, [int] $Port, [switch] $CategoryOnly, [switch] $Wait, [int] $TimeoutMinutes)
    throw 'Stub Start-WsusSync called: mock it.'
}

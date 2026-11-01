# Stub of the UpdateServices module for tests: only Get-WsusServer, which Find-CassiniUpdate
# calls. The body throws so an unmocked call fails loudly.

function Get-WsusServer {
    [CmdletBinding()]
    param ([string] $Name, [int] $PortNumber, [switch] $UseSsl)
    throw 'Stub Get-WsusServer called: mock it.'
}

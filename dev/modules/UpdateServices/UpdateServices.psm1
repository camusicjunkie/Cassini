# Fake UpdateServices module for running the portal without WSUS (dev/Start-DevServer.ps1).
# Only Get-WsusServer, returning an object whose SearchUpdates gives canned updates. Never deploy it.

function Get-WsusServer {
    [CmdletBinding()]
    param ([string] $Name, [int] $PortNumber, [switch] $UseSsl)

    $server = [PSCustomObject] @{ Name = $Name }
    $server | Add-Member -MemberType ScriptMethod -Name SearchUpdates -Value {
        param ([string] $Text)
        $declined = @(WSUS\Get-FakeWsusDeclined)
        foreach ($arch in 'x64', 'arm64') {
            [PSCustomObject] @{
                Title                 = "2026-10 Security Update for Microsoft Edge ($arch)"
                KnowledgebaseArticles = @($Text)
                ArrivalDate           = (Get-Date).AddDays(-6)
                IsDeclined            = $declined -contains "$Text-$arch"
                IsSuperseded          = $false
            }
        }
        # A look-alike KB that an exact match must leave out.
        [PSCustomObject] @{
            Title                 = 'Look-alike update'
            KnowledgebaseArticles = @("${Text}9")
            ArrivalDate           = (Get-Date).AddDays(-6)
            IsDeclined            = $false
            IsSuperseded          = $false
        }
    }
    $server
}

Export-ModuleMember -Function Get-WsusServer

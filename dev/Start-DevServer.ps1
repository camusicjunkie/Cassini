<#
.SYNOPSIS
    Runs the portal on this machine against fake WSUS data, with no sign-in.

.DESCRIPTION
    For working on the pages without a WSUS server: puts dev/modules (fake WSUS and UpdateServices
    modules with canned data) first on PSModulePath, writes a throwaway configuration with
    Authentication = None, and starts server.ps1 on http://localhost:<Port>. The audit log goes to
    a temp folder. Pode and Pode.Web must be installed.

    Name a server 'offline' (-ReplicaServer wsus02-offline.corp.local) to see an unreachable node.
.EXAMPLE
    ./dev/Start-DevServer.ps1
.EXAMPLE
    ./dev/Start-DevServer.ps1 -Port 8090 -ReplicaServer wsus02-offline.corp.local
#>
[CmdletBinding()]
param (
    # Local port.
    [int] $Port = 8080,

    # Replica name shown on the status page. Include 'offline' to fake an unreachable node.
    [string] $ReplicaServer = 'wsus02.corp.local'
)

$devModules = Join-Path -Path $PSScriptRoot -ChildPath 'modules'
$env:PSModulePath = $devModules + [IO.Path]::PathSeparator + $env:PSModulePath

$work = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath 'portcullis-dev'
$null = New-Item -ItemType Directory -Path $work -Force
$configPath = Join-Path -Path $work -ChildPath 'portcullis.psd1'
$auditPath = Join-Path -Path $work -ChildPath 'audit.log'

@"
@{
    UpstreamServer = 'wsus01.corp.local'
    ReplicaServer  = '$ReplicaServer'
    Authentication = 'None'
    ListenPort     = $Port
    AuditLogPath   = '$auditPath'
    Title          = 'Portcullis (dev)'
}
"@ | Set-Content -Path $configPath -Encoding UTF8

& (Join-Path -Path $PSScriptRoot -ChildPath '..\server.ps1') -ConfigPath $configPath

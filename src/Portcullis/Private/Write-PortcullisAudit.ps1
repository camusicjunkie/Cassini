function Write-PortcullisAudit {
    <#
    .SYNOPSIS
        Records who changed what through the portal.
    .DESCRIPTION
        Changes run as the portal's service account, so WSUS itself only sees that account. This
        record is what ties each change to the person who confirmed it.

        Writes one JSON line to the AuditLogPath file (creating its folder), and, when the event
        source 'Portcullis' is registered (see README), an Application event: ID 1000 for a change
        that succeeded, 1001 for one that failed. With AuditEventLog = 'Required' the server does not
        start without the source (Assert-PortcullisAuditSource). A failure to write the event is a warning; a
        failure to write the file throws, because a change must not go unrecorded.
    #>
    [CmdletBinding()]
    param (
        # Portal configuration from Get-PortcullisConfig.
        [Parameter(Mandatory)]
        [object] $Config,

        # The person who confirmed the change (Resolve-PortcullisUser).
        [Parameter(Mandatory)]
        [string] $User,

        # What was done, e.g. ApproveRing, DeclineUpdate, StartSync.
        [Parameter(Mandatory)]
        [string] $Action,

        # The node the change ran against.
        [Parameter(Mandatory)]
        [string] $Server,

        # Succeeded or Failed.
        [Parameter(Mandatory)]
        [ValidateSet('Succeeded', 'Failed')]
        [string] $Outcome,

        # Parameters and results worth keeping. Serialised as JSON.
        [hashtable] $Detail = @{}
    )

    $entry = [ordered]@{
        Time    = [datetime]::UtcNow.ToString('o')
        User    = $User
        Action  = $Action
        Server  = $Server
        Outcome = $Outcome
        Detail  = $Detail
    }
    $line = $entry | ConvertTo-Json -Depth 5 -Compress

    $folder = Split-Path -Path $Config.AuditLogPath -Parent
    if ($folder -and -not (Test-Path -LiteralPath $folder)) {
        $null = New-Item -ItemType Directory -Path $folder -Force
    }
    Add-Content -LiteralPath $Config.AuditLogPath -Value $line -Encoding UTF8

    try {
        if (Test-PortcullisEventSource) {
            $eventId = if ($Outcome -eq 'Succeeded') { 1000 } else { 1001 }
            $type = if ($Outcome -eq 'Succeeded') { 'Information' } else { 'Error' }
            [Diagnostics.EventLog]::WriteEntry('Portcullis', $line, $type, $eventId)
        }
    }
    catch {
        Write-Warning "Audit event not written (the file entry was): $($_.Exception.Message)"
    }
}

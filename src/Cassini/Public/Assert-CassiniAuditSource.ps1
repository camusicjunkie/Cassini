function Assert-CassiniAuditSource {
    <#
    .SYNOPSIS
        Refuses to start when the audit Event Log is required but its event source is missing.
    .DESCRIPTION
        The audit file is written by the portal's own account, which can also rewrite it. The
        Application event (forwarded to Splunk) is the copy that account cannot change. With
        AuditEventLog = 'Required' (the default under IIS), server.ps1 calls this before starting,
        so the portal never runs where changes would reach the file only.
    .EXAMPLE
        Assert-CassiniAuditSource -Config $config
    #>
    [CmdletBinding()]
    param (
        # Portal configuration from Get-CassiniConfig.
        [Parameter(Mandatory)]
        [object] $Config
    )

    if ($Config.AuditEventLog -eq 'Required' -and -not (Test-CassiniEventSource)) {
        throw "AuditEventLog is Required but the 'Cassini' event source is not registered. Run once, elevated: New-EventLog -LogName Application -Source Cassini"
    }
}

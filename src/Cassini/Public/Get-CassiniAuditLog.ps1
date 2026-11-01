function Get-CassiniAuditLog {
    <#
    .SYNOPSIS
        The newest portal audit entries, newest first, for the audit page.
    .DESCRIPTION
        Reads the JSON lines written for every change made through the portal. A line that is not
        valid JSON is skipped with a warning. No file yet (nothing changed) returns nothing.
    .EXAMPLE
        Get-CassiniAuditLog -Config $config -Last 20 | Format-Table
    .OUTPUTS
        Cassini.AuditEntry
    #>
    [CmdletBinding()]
    [OutputType('Cassini.AuditEntry')]
    param (
        # Portal configuration from Get-CassiniConfig.
        [Parameter(Mandatory)]
        [PSTypeName('Cassini.Config')]
        [object] $Config,

        # How many entries to return.
        [ValidateRange(1, 1000)]
        [int] $Last = 100
    )

    if (-not (Test-Path -LiteralPath $Config.AuditLogPath)) {
        return
    }

    $lines = @(Get-Content -LiteralPath $Config.AuditLogPath -Tail $Last -Encoding UTF8)
    [array]::Reverse($lines)

    foreach ($line in $lines) {
        if (-not $line) { continue }
        try {
            $entry = $line | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Warning "Skipped an audit line that is not valid JSON: $line"
            continue
        }
        [PSCustomObject] @{
            PSTypeName = 'Cassini.AuditEntry'
            Time       = Format-CassiniTime -Value $entry.Time
            User       = $entry.User
            Action     = $entry.Action
            Server     = $entry.Server
            Outcome    = $entry.Outcome
            Detail     = $entry.Detail | ConvertTo-Json -Depth 5 -Compress
        }
    }
}

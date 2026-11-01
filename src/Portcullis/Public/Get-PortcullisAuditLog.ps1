function Get-PortcullisAuditLog {
    <#
    .SYNOPSIS
        The newest portal audit entries, newest first, for the audit page.
    .DESCRIPTION
        Reads the JSON lines written for every change made through the portal. A line that is not
        valid JSON is skipped with a warning. No file yet (nothing changed) returns nothing.
    .EXAMPLE
        Get-PortcullisAuditLog -Config $config -Last 20 | Format-Table
    .OUTPUTS
        Portcullis.AuditEntry
    #>
    [CmdletBinding()]
    [OutputType('Portcullis.AuditEntry')]
    param (
        # Portal configuration from Get-PortcullisConfig.
        [Parameter(Mandatory)]
        [PSTypeName('Portcullis.Config')]
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
            PSTypeName = 'Portcullis.AuditEntry'
            Time       = Format-PortcullisTime -Value $entry.Time
            User       = $entry.User
            Action     = $entry.Action
            Server     = $entry.Server
            Outcome    = $entry.Outcome
            Detail     = $entry.Detail | ConvertTo-Json -Depth 5 -Compress
        }
    }
}

function Find-CassiniUpdate {
    <#
    .SYNOPSIS
        Lists the updates on the upstream for one KB, exactly as Deny-WsusUpdate would match them.
    .DESCRIPTION
        Read-only. This is the preview for a decline: WSUS\Deny-WsusUpdate -WhatIf returns nothing to
        show (it only writes "What if" text to the host), so the same exact-KB match is done here.
        KB5001234 matches every product and architecture variant of that KB and never KB50012345.

        Returns the matching updates and a preview record (New-CassiniPreview) for
        Invoke-CassiniDecline. NotFound is $true when the KB has no update on the upstream.

        This duplicates Deny-WsusUpdate's match rule. If the WSUS module gains a read-only
        Get-WsusUpdate -Kb, call that instead.
    .EXAMPLE
        (Find-CassiniUpdate -Config $config -Kb KB5001234).Rows
    .OUTPUTS
        Cassini.UpdateLookup
    #>
    [CmdletBinding()]
    [OutputType('Cassini.UpdateLookup')]
    param (
        # Portal configuration from Get-CassiniConfig.
        [Parameter(Mandatory)]
        [PSTypeName('Cassini.Config')]
        [object] $Config,

        # KB number, with or without the KB prefix.
        [Parameter(Mandatory)]
        [ValidatePattern('^\s*(KB)?\d+\s*$')]
        [string] $Kb
    )

    $number = $Kb.Trim() -replace '^KB', ''
    $wsus = UpdateServices\Get-WsusServer -Name $Config.UpstreamServer -PortNumber $Config.Port -UseSsl:($Config.Port -eq 8531)

    $rows = @(foreach ($update in $wsus.SearchUpdates($number)) {
            if ($number -notin $update.KnowledgebaseArticles) { continue }
            [PSCustomObject] @{
                PSTypeName = 'Cassini.UpdateRow'
                Kb         = "KB$number"
                Update     = $update.Title
                Arrived    = Format-CassiniTime -Value $update.ArrivalDate
                Declined   = [bool] $update.IsDeclined
                Superseded = [bool] $update.IsSuperseded
                OnConfirm  = if ($update.IsDeclined) { 'Already declined' } else { 'Decline' }
            }
        })

    [PSCustomObject] @{
        PSTypeName = 'Cassini.UpdateLookup'
        Kb         = "KB$number"
        Rows       = $rows
        NotFound   = $rows.Count -eq 0
        ToDecline  = @($rows | Where-Object { -not $_.Declined }).Count
        Preview    = New-CassiniPreview -Kind Decline -Parameters @{ Kb = "KB$number" }
    }
}

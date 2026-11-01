function Find-PortcullisUpdate {
    <#
    .SYNOPSIS
        Lists the updates on the upstream for one KB, exactly as Deny-WsusUpdate would match them.
    .DESCRIPTION
        Read-only. This is the preview for a decline: WSUS\Deny-WsusUpdate -WhatIf returns nothing to
        show (it only writes "What if" text to the host), so the same exact-KB match is done here.
        KB5001234 matches every product and architecture variant of that KB and never KB50012345.

        Returns the matching updates and a preview record (New-PortcullisPreview) for
        Invoke-PortcullisDecline. NotFound is $true when the KB has no update on the upstream.

        This duplicates Deny-WsusUpdate's match rule. If the WSUS module gains a read-only
        Get-WsusUpdate -Kb, call that instead.
    .EXAMPLE
        (Find-PortcullisUpdate -Config $config -Kb KB5001234).Rows
    .OUTPUTS
        Portcullis.UpdateLookup
    #>
    [CmdletBinding()]
    [OutputType('Portcullis.UpdateLookup')]
    param (
        # Portal configuration from Get-PortcullisConfig.
        [Parameter(Mandatory)]
        [PSTypeName('Portcullis.Config')]
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
                PSTypeName = 'Portcullis.UpdateRow'
                Kb         = "KB$number"
                Update     = $update.Title
                Arrived    = Format-PortcullisTime -Value $update.ArrivalDate
                Declined   = [bool] $update.IsDeclined
                Superseded = [bool] $update.IsSuperseded
                OnConfirm  = if ($update.IsDeclined) { 'Already declined' } else { 'Decline' }
            }
        })

    [PSCustomObject] @{
        PSTypeName = 'Portcullis.UpdateLookup'
        Kb         = "KB$number"
        Rows       = $rows
        NotFound   = $rows.Count -eq 0
        ToDecline  = @($rows | Where-Object { -not $_.Declined }).Count
        Preview    = New-PortcullisPreview -Kind Decline -Parameters @{ Kb = "KB$number" }
    }
}

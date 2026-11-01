function New-PortcullisPreview {
    <#
    .SYNOPSIS
        Records what a preview showed, so the confirm step runs exactly that and nothing else.
    .DESCRIPTION
        The web server keeps the returned hashtable in the user's session. The confirm step passes
        it back to Invoke-PortcullisRingApproval or Invoke-PortcullisDecline, which:
          - run with the Parameters recorded here, never with values posted by the browser;
          - refuse a preview of the wrong Kind, or one older than PreviewMaxAgeMinutes;
          - refuse a preview whose Id differs from the one the confirm dialog was opened for.

        Only strings, numbers and booleans are stored, so the session store can serialise it.
    .EXAMPLE
        $preview = New-PortcullisPreview -Kind Decline -Parameters @{ Kb = 'KB5001234' }
    .OUTPUTS
        System.Collections.Hashtable
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Builds an in-memory record only; nothing on a node changes.')]
    param (
        # What was previewed: Ring (Approve-WsusRing) or Decline (Deny-WsusUpdate).
        [Parameter(Mandatory)]
        [ValidateSet('Ring', 'Decline')]
        [string] $Kind,

        # The parameters the confirm step will run with.
        [Parameter(Mandatory)]
        [hashtable] $Parameters
    )

    @{
        Id         = [guid]::NewGuid().ToString()
        Kind       = $Kind
        Parameters = $Parameters.Clone()
        CreatedUtc = [datetime]::UtcNow.ToString('o')
    }
}

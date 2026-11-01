function Invoke-CassiniDecline {
    <#
    .SYNOPSIS
        Confirms a decline preview: declines the previewed KB on the upstream with WSUS\Deny-WsusUpdate.
    .DESCRIPTION
        The preview (from Find-CassiniUpdate, kept in the user's session) must still be valid: see
        Assert-CassiniPreview. The KB comes from the preview, never from the browser. The replica
        picks the decline up on its next sync.

        Returns Deny-WsusUpdate's rows (Kb, Update, Action, NextStep). Every run is audited, including
        runs that throw or find nothing.
    .EXAMPLE
        Invoke-CassiniDecline -Config $config -Preview $preview -PreviewId $preview.Id -User 'CORP\jsteele'
    .OUTPUTS
        WSUS.DeclineResult
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType('WSUS.DeclineResult')]
    param (
        # Portal configuration from Get-CassiniConfig.
        [Parameter(Mandatory)]
        [PSTypeName('Cassini.Config')]
        [object] $Config,

        # The stored preview (the Preview property of Find-CassiniUpdate's output).
        [AllowNull()]
        [hashtable] $Preview,

        # The preview Id the confirm dialog was opened for.
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $PreviewId,

        # The person confirming (Resolve-CassiniUser).
        [Parameter(Mandatory)]
        [string] $User
    )

    Assert-CassiniPreview -Preview $Preview -Kind Decline -PreviewId $PreviewId -MaxAgeMinutes $Config.PreviewMaxAgeMinutes
    $kb = $Preview.Parameters.Kb

    if (-not $PSCmdlet.ShouldProcess("$kb on $($Config.UpstreamServer)", 'Decline update')) {
        return
    }

    $audit = @{
        Config = $Config
        User   = $User
        Action = 'DeclineUpdate'
        Server = $Config.UpstreamServer
    }

    $declineError = $null
    try {
        $result = @(WSUS\Deny-WsusUpdate -Kb $kb -WsusServer $Config.UpstreamServer -Port $Config.Port -Confirm:$false -ErrorVariable declineError)
    }
    catch {
        Write-CassiniAudit @audit -Outcome Failed -Detail @{ Kb = $kb; Error = $_.Exception.Message }
        throw
    }

    if ($declineError) {
        Write-CassiniAudit @audit -Outcome Failed -Detail @{ Kb = $kb; Error = $declineError[0].Exception.Message }
        throw $declineError[0]
    }

    Write-CassiniAudit @audit -Outcome Succeeded -Detail @{
        Kb       = $kb
        Declined = @($result | Where-Object Action -eq 'Declined').Count
        Already  = @($result | Where-Object Action -eq 'AlreadyDeclined').Count
    }
    $result
}

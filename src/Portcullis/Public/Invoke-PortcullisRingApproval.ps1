function Invoke-PortcullisRingApproval {
    <#
    .SYNOPSIS
        Confirms a ring preview: runs Approve-WsusRing for real with the previewed gate settings.
    .DESCRIPTION
        The preview (from Get-PortcullisRingPreview, kept in the user's session) must still be valid:
        see Assert-PortcullisPreview. The gate is evaluated again at this moment, so the result can
        differ from the preview if Pilot installs changed in between; the returned rows are what
        actually happened (ApprovedTo names the groups each update was approved for).

        Every run is audited with the user, the gate settings and the approval counts, including runs
        that throw.
    .EXAMPLE
        Invoke-PortcullisRingApproval -Config $config -Preview $preview -PreviewId $preview.Id -User 'CORP\jsteele'
    .OUTPUTS
        Portcullis.RingResult
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType('Portcullis.RingResult')]
    param (
        # Portal configuration from Get-PortcullisConfig.
        [Parameter(Mandatory)]
        [PSTypeName('Portcullis.Config')]
        [object] $Config,

        # The stored preview (the Preview property of Get-PortcullisRingPreview's output).
        [AllowNull()]
        [hashtable] $Preview,

        # The preview Id the confirm dialog was opened for.
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $PreviewId,

        # The person confirming (Resolve-PortcullisUser).
        [Parameter(Mandatory)]
        [string] $User
    )

    Assert-PortcullisPreview -Preview $Preview -Kind Ring -PreviewId $PreviewId -MaxAgeMinutes $Config.PreviewMaxAgeMinutes
    $parameters = $Preview.Parameters

    if (-not $PSCmdlet.ShouldProcess($Config.UpstreamServer, 'Approve gated updates for the next rings')) {
        return
    }

    $audit = @{
        Config = $Config
        User   = $User
        Action = 'ApproveRing'
        Server = $Config.UpstreamServer
    }

    try {
        $result = @(WSUS\Approve-WsusRing @parameters -WsusServer $Config.UpstreamServer -Port $Config.Port -Confirm:$false -WarningAction SilentlyContinue)
    }
    catch {
        Write-PortcullisAudit @audit -Outcome Failed -Detail @{ Parameters = $parameters; Error = $_.Exception.Message }
        throw
    }

    $rows = foreach ($row in $result) {
        [PSCustomObject] @{
            PSTypeName = 'Portcullis.RingResult'
            Kb         = Format-PortcullisKb -Value $row.Kb
            Update     = $row.Update
            Gate       = $row.Gate
            ApprovedTo = @($row.ApprovedTo) -join ', '
            Reason     = ConvertTo-PortcullisSentence -Text (@($row.Reason) -join '; ')
        }
    }

    $approved = @($rows | Where-Object ApprovedTo)
    Write-PortcullisAudit @audit -Outcome Succeeded -Detail @{
        Parameters = $parameters
        Approved   = @($approved.Kb)
        Held       = @($rows | Where-Object Gate -eq 'Held').Count
    }
    $rows
}

function Invoke-CassiniRingApproval {
    <#
    .SYNOPSIS
        Confirms a ring preview: runs Approve-WsusRing for real with the previewed gate settings.
    .DESCRIPTION
        The preview (from Get-CassiniRingPreview, kept in the user's session) must still be valid:
        see Assert-CassiniPreview. The gate is evaluated again at this moment, so the result can
        differ from the preview if Pilot installs changed in between; the returned rows are what
        actually happened (ApprovedTo names the groups each update was approved for).

        Every run is audited with the user, the gate settings and the approval counts, including runs
        that throw.
    .EXAMPLE
        Invoke-CassiniRingApproval -Config $config -Preview $preview -PreviewId $preview.Id -User 'CORP\jsteele'
    .OUTPUTS
        Cassini.RingResult
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType('Cassini.RingResult')]
    param (
        # Portal configuration from Get-CassiniConfig.
        [Parameter(Mandatory)]
        [PSTypeName('Cassini.Config')]
        [object] $Config,

        # The stored preview (the Preview property of Get-CassiniRingPreview's output).
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

    Assert-CassiniPreview -Preview $Preview -Kind Ring -PreviewId $PreviewId -MaxAgeMinutes $Config.PreviewMaxAgeMinutes
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
        Write-CassiniAudit @audit -Outcome Failed -Detail @{ Parameters = $parameters; Error = $_.Exception.Message }
        throw
    }

    $rows = foreach ($row in $result) {
        [PSCustomObject] @{
            PSTypeName = 'Cassini.RingResult'
            Kb         = Format-CassiniKb -Value $row.Kb
            Update     = $row.Update
            Gate       = $row.Gate
            ApprovedTo = @($row.ApprovedTo) -join ', '
            Reason     = ConvertTo-CassiniSentence -Text (@($row.Reason) -join '; ')
        }
    }

    $approved = @($rows | Where-Object ApprovedTo)
    Write-CassiniAudit @audit -Outcome Succeeded -Detail @{
        Parameters = $parameters
        Approved   = @($approved.Kb)
        Held       = @($rows | Where-Object Gate -eq 'Held').Count
    }
    $rows
}

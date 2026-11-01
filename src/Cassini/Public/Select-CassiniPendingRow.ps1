function Select-CassiniPendingRow {
    <#
    .SYNOPSIS
        The preview rows still pending after an approval: those that were not approved.
    .DESCRIPTION
        After Invoke-CassiniRingApproval, the preview on the page is out of date: the updates that
        were just approved are no longer candidates. This returns the preview rows to keep showing,
        matched by update title (one KB can cover several updates, and a title is unique).

        An update counts as approved when its approval row has groups in ApprovedTo. A held update,
        or one the gate passed but that was not approved this time, stays pending.
    .EXAMPLE
        Select-CassiniPendingRow -PreviewRow $preview.Rows -ApprovalRow $result
    .OUTPUTS
        Cassini.RingRow
    #>
    [CmdletBinding()]
    [OutputType('Cassini.RingRow')]
    param (
        # The rows shown in the preview (Get-CassiniRingPreview).
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]] $PreviewRow,

        # The rows returned by Invoke-CassiniRingApproval.
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]] $ApprovalRow
    )

    $approved = @(($ApprovalRow | Where-Object { $_.ApprovedTo }).Update)
    $PreviewRow | Where-Object { $_ -and $_.Update -notin $approved }
}

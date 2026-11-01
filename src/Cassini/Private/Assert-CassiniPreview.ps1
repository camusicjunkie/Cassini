function Assert-CassiniPreview {
    <#
    .SYNOPSIS
        Throws unless a stored preview can still be confirmed.
    .DESCRIPTION
        The one place that decides whether a confirm step may run: the preview exists, is of the
        expected Kind, matches the Id the confirm dialog was opened for, and is younger than the
        configured PreviewMaxAgeMinutes. Every message ends by telling the user to preview again.
    #>
    [CmdletBinding()]
    param (
        # The preview from the session (New-CassiniPreview), or $null if there is none.
        [AllowNull()]
        [object] $Preview,

        # The Kind the caller runs.
        [Parameter(Mandatory)]
        [ValidateSet('Ring', 'Decline')]
        [string] $Kind,

        # The Id the confirm dialog was opened for.
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $PreviewId,

        # How old the preview may be.
        [Parameter(Mandatory)]
        [int] $MaxAgeMinutes
    )

    $again = 'Run the preview again.'
    if (-not $Preview) {
        throw "There is no preview to confirm. $again"
    }
    if ($Preview.Kind -ne $Kind) {
        throw "The stored preview is a $($Preview.Kind) preview, not a $Kind preview. $again"
    }
    if ($Preview.Id -ne $PreviewId) {
        throw "This confirmation belongs to an older preview. $again"
    }

    $created = [datetime]::Parse($Preview.CreatedUtc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind)
    if ([datetime]::UtcNow - $created -gt [timespan]::FromMinutes($MaxAgeMinutes)) {
        throw "The preview is more than $MaxAgeMinutes minutes old. $again"
    }
}

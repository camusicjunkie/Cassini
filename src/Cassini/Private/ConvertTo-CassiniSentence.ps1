function ConvertTo-CassiniSentence {
    <#
    .SYNOPSIS
        Capitalises the first letter of a sentence for display.
    .DESCRIPTION
        The WSUS module writes gate reasons in lower case ("only 63% installed in Pilot") because it
        joins them into one line. The portal shows each one as a sentence. Only the first character
        changes; the rest (KB numbers, ring names) is left as it is. Empty input gives ''.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        # The text to convert.
        [Parameter(ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Text
    )

    process {
        $trimmed = $Text -replace '^\s+', ''
        if (-not $trimmed) {
            return ''
        }
        # No PowerShell operator changes case; this is the one string method used for it.
        "$($trimmed[0])".ToUpperInvariant() + ($trimmed -replace '^.', '')
    }
}

function Format-PortcullisTime {
    <#
    .SYNOPSIS
        Formats a date for the web tables as 'yyyy-MM-dd HH:mm' in the server's local time.
    .DESCRIPTION
        $null, or anything that is not a date, gives $null so the table cell stays empty.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        # The value to format.
        [AllowNull()]
        [object] $Value
    )

    $date = $Value -as [datetime]
    if (-not $date) {
        return $null
    }
    $date.ToString('yyyy-MM-dd HH:mm')
}

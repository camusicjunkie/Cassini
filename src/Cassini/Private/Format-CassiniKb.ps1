function Format-CassiniKb {
    <#
    .SYNOPSIS
        Shows KB numbers the way people search for them: 'KB5001234'.
    .DESCRIPTION
        Approve-WsusRing joins an update's KnowledgebaseArticles with ', ' and WSUS stores them without
        the prefix. Each number gets 'KB' once; anything already prefixed is left alone.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        # One or more KB numbers, possibly joined with ', '.
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Value
    )

    if (-not $Value) {
        return ''
    }
    (($Value -split '\s*,\s*') | Where-Object { $_ } | ForEach-Object { $_ -replace '^(KB)?', 'KB' }) -join ', '
}

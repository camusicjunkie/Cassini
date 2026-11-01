function Test-CassiniEventSource {
    <#
    .SYNOPSIS
        True when the 'Cassini' Application event source is registered on this machine.
    .DESCRIPTION
        False where the Event Log is not available (not Windows) or cannot be read. Kept separate so
        tests can mock it.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    try {
        [Diagnostics.EventLog]::SourceExists('Cassini')
    }
    catch {
        $false
    }
}

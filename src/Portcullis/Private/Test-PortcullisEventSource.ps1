function Test-PortcullisEventSource {
    <#
    .SYNOPSIS
        True when the 'Portcullis' Application event source is registered on this machine.
    .DESCRIPTION
        False where the Event Log is not available (not Windows) or cannot be read. Kept separate so
        tests can mock it.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    try {
        [Diagnostics.EventLog]::SourceExists('Portcullis')
    }
    catch {
        $false
    }
}

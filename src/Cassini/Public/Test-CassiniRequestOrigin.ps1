function Test-CassiniRequestOrigin {
    <#
    .SYNOPSIS
        Decides whether a request may change something: refuses one sent from another site (CSRF).
    .DESCRIPTION
        Windows Authentication signs every request in automatically, including one that another page
        makes the browser send. Every Pode.Web action is a POST from the portal's own pages, so a POST
        that a browser marks as coming from elsewhere is refused. Pode.Web has no CSRF tokens, so this
        uses what the browser sends instead:

          Sec-Fetch-Site  Allowed when 'same-origin' or 'none' (typed or bookmarked). 'same-site' is
                          refused: another intranet site under the same domain is exactly the case
                          to stop.
          Origin          Used when Sec-Fetch-Site is missing (older browsers). Allowed when its
                          host and port match the Host header; 'null' is refused.

        A request with neither header is allowed: browsers send at least Origin on every POST, so it
        comes from a script (Invoke-RestMethod), which cannot be tricked into sending a request.
        GET, HEAD and OPTIONS are always allowed; nothing in the portal changes on them.

        Returns an object with Allowed and Reason, so the refusal can be logged.
    .EXAMPLE
        Test-CassiniRequestOrigin -Method POST -FetchSite 'cross-site' -Origin 'https://evil.blue.local' -HostHeader 'cassini.blue.local'
        Allowed = False.
    .OUTPUTS
        Cassini.OriginCheck
    #>
    [CmdletBinding()]
    [OutputType('Cassini.OriginCheck')]
    param (
        # HTTP method of the request.
        [Parameter(Mandatory)]
        [string] $Method,

        # Value of the Sec-Fetch-Site header, if any.
        [AllowNull()]
        [AllowEmptyString()]
        [string] $FetchSite,

        # Value of the Origin header, if any.
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Origin,

        # Value of the Host header (the name the browser used to reach the portal).
        [AllowNull()]
        [AllowEmptyString()]
        [string] $HostHeader
    )

    $result = {
        param ([bool] $Allowed, [string] $Reason)
        [PSCustomObject] @{ PSTypeName = 'Cassini.OriginCheck'; Allowed = $Allowed; Reason = $Reason }
    }

    if ($Method -in 'GET', 'HEAD', 'OPTIONS') {
        return & $result $true "$Method changes nothing."
    }

    if ($FetchSite) {
        if ($FetchSite -in 'same-origin', 'none') {
            return & $result $true "Sec-Fetch-Site is $FetchSite."
        }
        return & $result $false "Sent from another site (Sec-Fetch-Site: $FetchSite)."
    }

    if ($Origin) {
        $originUri = $Origin -as [uri]
        if ($Origin -eq 'null' -or -not $originUri -or -not $originUri.IsAbsoluteUri) {
            return & $result $false "Origin '$Origin' is not a site."
        }
        $defaultPort = if ($originUri.Scheme -eq 'https') { 443 } else { 80 }
        $hostName, $hostPort = $HostHeader -split ':', 2
        $hostPort = if ($hostPort) { $hostPort -as [int] } else { $defaultPort }
        if ($hostName -and $originUri.Host -eq $hostName -and $originUri.Port -eq $hostPort) {
            return & $result $true 'Origin matches the Host header.'
        }
        return & $result $false "Sent from another site (Origin: $Origin, Host: $HostHeader)."
    }

    & $result $true 'No browser origin headers: not sent by a browser.'
}

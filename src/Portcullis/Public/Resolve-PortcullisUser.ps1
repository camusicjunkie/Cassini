function Resolve-PortcullisUser {
    <#
    .SYNOPSIS
        The name recorded in the audit log for the person using the portal.
    .DESCRIPTION
        With IIS (Windows) authentication, Pode puts the signed-in user in $WebEvent.Auth.User:
        the result is DOMAIN\username. With Authentication = None (local development only) there is
        no signed-in user, so the result names the account running the portal and says so.
    .EXAMPLE
        Resolve-PortcullisUser -AuthUser $WebEvent.Auth.User
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        # $WebEvent.Auth.User from Pode, or $null when no authentication is configured.
        [AllowNull()]
        [object] $AuthUser
    )

    if ($AuthUser -and $AuthUser.Username) {
        if ($AuthUser.Domain) {
            return '{0}\{1}' -f $AuthUser.Domain, $AuthUser.Username
        }
        return [string] $AuthUser.Username
    }

    $account = [Environment]::UserName
    if ([Environment]::UserDomainName) {
        $account = '{0}\{1}' -f [Environment]::UserDomainName, $account
    }
    "$account (no authentication)"
}

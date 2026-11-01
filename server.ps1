<#
.SYNOPSIS
    Starts the Cassini WSUS admin portal (Pode + Pode.Web).

.DESCRIPTION
    Five pages:
      Status    Both nodes from Get-WsusNodeStatus, refreshed every minute; start a sync on either node.
      Calendar  The month's patch cycle: Patch Tuesday, what to do when, and when each ring installs
                (from the ring GPOs; GET /api/v1/calendar feeds it).
      Rings     Preview the Approve-WsusRing gate, then confirm to approve what passed; says when the
                rings will install.
      Decline  Look up a KB on the upstream, then confirm to decline it.
      Audit    The newest changes made through the portal, with who confirmed them.

    Every change is a two-step preview then confirm. The confirm step runs the parameters stored
    with the preview in the user's session (never values posted by the browser) and is refused once
    the preview is older than PreviewMaxAgeMinutes. Every change is written to the audit log.

    Run under IIS with Windows Authentication (docs/hosting-iis.md); only members of AdminGroup get
    in. Authentication = None in the configuration is for local development: it refuses to start
    under IIS, and listens on localhost only.

    Security controls set here (docs/security.md): POSTs from other sites are refused, the session
    cookie is Secure, HttpOnly and SameSite=Strict with an idle time-out of SessionMinutes, every
    response carries a Content-Security-Policy and other security headers, and with
    AuditEventLog = 'Required' the server does not start without the audit event source.

    The logic lives in the Cassini module (src/Cassini); this file is only the web layout.

.EXAMPLE
    ./server.ps1 -ConfigPath ./config/cassini.psd1
#>
#Requires -Version 5.1
[CmdletBinding()]
param (
    # Portal configuration file (see config/cassini.example.psd1).
    [string] $ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'config\cassini.psd1')
)

$ErrorActionPreference = 'Stop'

$cassiniManifest = Join-Path -Path $PSScriptRoot -ChildPath 'src\Cassini\Cassini.psd1'
# Cassini's manifest brings in the pinned Pode and Pode.Web; a missing or wrong version fails here.
Import-Module -Name WSUS
Import-Module -Name $cassiniManifest -Force
$config = Get-CassiniConfig -Path $ConfigPath
Assert-CassiniAuditSource -Config $config

Start-PodeServer -RootPath $PSScriptRoot -ScriptBlock {
    # Route and element scriptblocks run in their own runspaces: give them the modules and config.
    Import-PodeModule -Name WSUS
    Import-PodeModule -Path $cassiniManifest
    Set-PodeState -Name 'Config' -Value $config

    # When each ring installs, read from the ring GPOs (or the configuration). Read again every hour
    # so a GPO change shows without a restart.
    Set-PodeState -Name 'Schedule' -Value @(Get-CassiniInstallSchedule -Config $config)
    Add-PodeTimer -Name 'RefreshSchedule' -Interval 3600 -ScriptBlock {
        Set-PodeState -Name 'Schedule' -Value @(Get-CassiniInstallSchedule -Config (Get-PodeState -Name 'Config'))
    }

    New-PodeLogFileMethod -Name 'cassini_errors' | Enable-PodeLogErrorType

    if ($config.Authentication -eq 'None' -and (Test-PodeIsIIS)) {
        throw 'Authentication = None is for local development and is refused under IIS. Set Authentication = IIS.'
    }
    # Under IIS, Pode replaces this endpoint with the one IIS assigns.
    Add-PodeEndpoint -Address localhost -Port $config.ListenPort -Protocol Http

    # Idle time-out, renewed on each request. Secure: browsers send the cookie over HTTPS only (and to
    # http://localhost for development). HttpOnly: page scripts cannot read it. Strict: the session is
    # also bound to the browser's user agent. Pode cannot set SameSite on this cookie; see
    # docs/security.md for the IIS rule that adds it.
    Enable-PodeSessionMiddleware -Duration ($config.SessionMinutes * 60) -Extend -Secure -HttpOnly -Strict

    # Windows Authentication signs in any request the browser sends, including one another page
    # triggers. Refuse POSTs that the browser marks as coming from another site (CSRF).
    Add-PodeMiddleware -Name 'CassiniSameOrigin' -ScriptBlock {
        $check = Test-CassiniRequestOrigin -Method $WebEvent.Method -FetchSite (Get-PodeHeader -Name 'Sec-Fetch-Site') `
            -Origin (Get-PodeHeader -Name 'Origin') -HostHeader (Get-PodeHeader -Name 'Host')
        if ($check.Allowed) {
            return $true
        }
        Write-PodeErrorLog -Message "Refused $($WebEvent.Method) $($WebEvent.Path): $($check.Reason)"
        Set-PodeResponseStatus -Code 403 -Description 'Requests from other sites are refused.' -NoErrorPage
        return $false
    }

    Initialize-PodeWebTemplates -Title $config.Title -Theme Auto -NoPageFilter -Security None

    # Security headers on every response, set after Pode.Web (started with -Security None, whose
    # presets allow any origin for CORS and inline scripts). All scripts are files served by the
    # portal, so scripts are 'self' only; Pode.Web sets inline style attributes, so styles allow
    # 'unsafe-inline'. No CORS headers: only the portal's own pages call it.
    Set-PodeSecurityContentSecurityPolicy -Default 'self' -Scripts 'self' -Style 'self', 'unsafe-inline' `
        -Image 'self', 'data' -Font 'self', 'data' -Connect 'self' -Object 'none' -BaseUri 'self' `
        -FormAction 'self' -FrameAncestor 'none'
    Set-PodeSecurityFrameOptions -Type Deny
    Set-PodeSecurityContentTypeOptions
    Set-PodeSecurityReferrerPolicy -Type 'No-Referrer'
    Set-PodeSecurityCrossOrigin -Open 'Same-Origin' -Resource 'Same-Origin'
    Set-PodeSecurityPermissionsPolicy -Camera 'none' -Microphone 'none' -Geolocation 'none' -Payment 'none' -Usb 'none'
    # Browsers only act on HSTS over HTTPS, so it is harmless on http://localhost.
    Set-PodeSecurityStrictTransportSecurity -Duration 31536000
    Hide-PodeSecurityServer

    # Layout fixes (whole words in table cells, spaced buttons, hamburger and icon rail for the
    # collapsed sidebar) and page-name tooltips for that rail.
    # The file's hash goes in the URL, so browsers fetch the new file after an upgrade instead of
    # keeping the cached one for up to an hour (static caching is on in server.psd1).
    $assetVersion = @{}
    foreach ($asset in 'cassini.css', 'cassini.js') {
        $assetPath = Join-Path -Path $PSScriptRoot -ChildPath "public\$asset"
        $assetVersion[$asset] = (Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash -replace '^(.{12}).*$', '$1'
    }
    Import-PodeWebStylesheet -Url "/cassini.css?v=$($assetVersion['cassini.css'])"
    Import-PodeWebJavaScript -Url "/cassini.js?v=$($assetVersion['cassini.js'])"

    if ($config.Authentication -eq 'IIS') {
        # Windows Authentication in IIS; nested AD membership counts.
        Add-PodeAuthIIS -Name 'Windows' -Groups $config.AdminGroup -FailureMessage "You need to be a member of $($config.AdminGroup)."
        Set-PodeWebAuth -Authentication 'Windows'
    }

    # ---------------------------------------------------------------- Status
    Add-PodeWebPage -Name 'Status' -Path '/' -Icon 'server' -HomePage -Index 0 -Content @(
        New-PodeWebCard -Name 'Nodes' -Content @(
            New-PodeWebParagraph -Value 'Facts from Get-WsusNodeStatus, refreshed every minute. Disk and log facts are only available on the node itself, so they are not shown here.'
            New-PodeWebTable -Name 'NodeStatus' -DisplayName 'Nodes' -Compact -AutoRefresh -RefreshInterval 60 -NoExport -Columns @(
                Initialize-PodeWebTableColumn -Key 'LastSync' -Name 'Last sync'
                Initialize-PodeWebTableColumn -Key 'LastSyncResult' -Name 'Last sync result'
                Initialize-PodeWebTableColumn -Key 'DownloadPendingMB' -Name 'To download (MB)'
                Initialize-PodeWebTableColumn -Key 'DownloadFailed' -Name 'Download failures'
            ) -ScriptBlock {
                Get-CassiniNodeStatus -Config (Get-PodeState -Name 'Config') |
                    Select-Object -Property Node, Server, Sync, LastSync, LastSyncResult, Updates, Approved, Declined, DownloadPendingMB, DownloadFailed, Note
            }
        )
        New-PodeWebCard -Name 'Sync' -Content @(
            New-PodeWebParagraph -Value 'Starts a full sync and returns at once; watch progress in the table above. Nothing starts if a sync is already running.'
            New-PodeWebButton -Name 'SyncUpstream' -DisplayName 'Sync upstream' -Icon 'sync' -ScriptBlock {
                Show-PodeWebModal -Name 'ConfirmSync' -DataValue 'Upstream' -Actions @(
                    Update-PodeWebText -Id 'sync_node' -Value "the upstream ($((Get-PodeState -Name 'Config').UpstreamServer))"
                )
            }
            if ($config.ReplicaServer) {
                New-PodeWebButton -Name 'SyncReplica' -DisplayName 'Sync replica' -Icon 'sync' -ScriptBlock {
                    Show-PodeWebModal -Name 'ConfirmSync' -DataValue 'Replica' -Actions @(
                        Update-PodeWebText -Id 'sync_node' -Value "the replica ($((Get-PodeState -Name 'Config').ReplicaServer))"
                    )
                }
            }
        )
        New-PodeWebModal -Name 'ConfirmSync' -DisplayName 'Start sync' -SubmitText 'Start sync' -Content @(
            New-PodeWebText -Value 'Start a full sync on '
            New-PodeWebText -Id 'sync_node'
            New-PodeWebText -Value '?'
        ) -ScriptBlock {
            $user = Resolve-CassiniUser -AuthUser $WebEvent.Auth.User
            try {
                $result = Invoke-CassiniSync -Config (Get-PodeState -Name 'Config') -Node $WebEvent.Data.Value -User $user -Confirm:$false
                $message = if ($result.Status -eq 'AlreadyRunning') { 'A sync is already running; nothing new started.' } else { "Sync started on $($result.Server)." }
                Show-PodeWebToast -Title 'Sync' -Message $message
            }
            catch {
                Show-PodeWebToast -Title 'Sync failed' -Message $_.Exception.Message -Duration 15000
            }
            Hide-PodeWebModal
            Sync-PodeWebTable -Name 'NodeStatus'
        }
    )

    # ---------------------------------------------------------------- Calendar
    # Read-only JSON for the calendar grid (public/cassini.js). Same sign-in as the pages.
    $routeAuth = if ($config.Authentication -eq 'IIS') { @{ Authentication = 'Windows' } } else { @{} }
    Add-PodeRoute -Method Get -Path '/api/v1/calendar' @routeAuth -ScriptBlock {
        $month = $WebEvent.Query['month']
        $date = if ($month -match '^20\d{2}-(0[1-9]|1[0-2])$') {
            [datetime]::ParseExact("$month-01", 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        }
        else {
            (Get-Date).Date
        }
        $schedule = @(Get-PodeState -Name 'Schedule')
        Write-PodeJsonResponse -Depth 4 -Value @{
            month    = $date.ToString('yyyy-MM')
            today    = (Get-Date).ToString('yyyy-MM-dd')
            events   = @(Get-CassiniPatchCalendar -Schedule $schedule -Month $date |
                    Select-Object -Property Date, Time, Kind, Ring, Title, Detail)
            schedule = @($schedule | Select-Object -Property Ring, Day, Hour, DetectionHours, Source)
            warnings = @($schedule | Where-Object { $_.Warning } | ForEach-Object { $_.Warning })
        }
    }

    Add-PodeWebPage -Name 'Calendar' -DisplayName 'Patch calendar' -Index 1 -Icon 'calendar-month' -Content @(
        New-PodeWebCard -Name 'Cycle' -DisplayName 'Patch cycle' -Content @(
            # Drawn by public/cassini.js from /api/v1/calendar.
            New-PodeWebRaw -Value "<div id='cs-calendar' class='cs-calendar'></div>"
        )
    )

    # ---------------------------------------------------------------- Rings
    Add-PodeWebPage -Name 'Rings' -DisplayName 'Promote rings' -Index 2 -Icon 'stairs-up' -Content @(
        New-PodeWebCard -Name 'Gate' -DisplayName 'Gate settings' -Content @(
            New-PodeWebParagraph -Value 'Previews Approve-WsusRing on the upstream: Critical and Security updates approved for Pilot, checked against the gate. Nothing is approved until you confirm. The Patch calendar shows this month''s dates.'
            New-PodeWebForm -Name 'RingGate' -SubmitText 'Preview' -Content @(
                New-PodeWebTextbox -Name 'MinimumSoakDays' -DisplayName 'Minimum soak (days)' -Type Number -Value 5 -Required
                New-PodeWebTextbox -Name 'MinimumInstalledPercent' -DisplayName 'Minimum installed in Pilot (%)' -Type Number -Value 90 -Required
                New-PodeWebCheckbox -Name 'Force' -DisplayName 'Force: approve updates that fail the gate (out-of-band updates only)' -AsSwitch
            ) -ScriptBlock {
                $soak = $WebEvent.Data.MinimumSoakDays -as [int]
                $percent = $WebEvent.Data.MinimumInstalledPercent -as [int]
                if ($null -eq $soak -or $soak -notin 0..60 -or $null -eq $percent -or $percent -notin 0..100) {
                    Show-PodeWebToast -Title 'Check the settings' -Message 'Soak must be 0 to 60 days and installed percent 0 to 100.'
                    return
                }

                try {
                    $result = Get-CassiniRingPreview -Config (Get-PodeState -Name 'Config') -MinimumSoakDays $soak -MinimumInstalledPercent $percent -Force:($WebEvent.Data.Force -eq 'true')
                }
                catch {
                    $WebEvent.Session.Data.Remove('RingPreview')
                    $WebEvent.Session.Data.Remove('RingPreviewRows')
                    Disable-PodeWebButton -Name 'ApproveRing'
                    Show-PodeWebToast -Title 'Preview failed' -Message $_.Exception.Message -Duration 15000
                    return
                }

                $WebEvent.Session.Data.RingPreview = $result.Preview
                $WebEvent.Session.Data.RingPreviewRows = @($result.Rows)
                $summary = $result.Summary
                $text = 'Candidates: {0}. Would be approved: {1} ({2} forced). Held: {3}.' -f $summary.Candidates, $summary.Approvable, $summary.Forced, $summary.Held
                if ($summary.Approvable -gt 0) {
                    $installs = try { Format-CassiniInstallTime -Schedule (Get-PodeState -Name 'Schedule') } catch { '' }
                    if ($installs) {
                        $text += " If approved now: $($installs -replace '^Installs', 'installs')"
                    }
                }
                Update-PodeWebText -Id 'ring_summary' -Value $text
                Update-PodeWebTable -Name 'RingPreview' -Data $result.Rows
                if ($summary.Approvable -gt 0) { Enable-PodeWebButton -Name 'ApproveRing' } else { Disable-PodeWebButton -Name 'ApproveRing' }
            }
        )
        New-PodeWebCard -Name 'Preview' -Content @(
            New-PodeWebText -Id 'ring_summary' -Value 'Run a preview to see the gate.'
            New-PodeWebTable -Name 'RingPreview' -DisplayName 'Gate' -Compact -NoExport -Columns @(
                Initialize-PodeWebTableColumn -Key 'Kb' -Name 'KB'
                Initialize-PodeWebTableColumn -Key 'Installed' -Name 'Installed in Pilot'
                Initialize-PodeWebTableColumn -Key 'Failed' -Name 'Failed in Pilot'
                Initialize-PodeWebTableColumn -Key 'OnConfirm' -Name 'On confirm'
            )
            New-PodeWebButton -Name 'ApproveRing' -DisplayName 'Approve what passed' -Icon 'check-decagram' -Colour Green -Disabled -ScriptBlock {
                $preview = $WebEvent.Session.Data.RingPreview
                $id = if ($preview -and $preview.Kind -eq 'Ring') { $preview.Id } else { '' }
                Show-PodeWebModal -Name 'ConfirmRing' -DataValue $id
            }
        )
        New-PodeWebCard -Name 'Result' -DisplayName 'Last approval' -Content @(
            New-PodeWebText -Id 'ring_result_when' -Value ''
            New-PodeWebTable -Name 'RingResult' -DisplayName 'What was approved' -Compact -NoRefresh -NoExport -Columns @(
                Initialize-PodeWebTableColumn -Key 'Kb' -Name 'KB'
                Initialize-PodeWebTableColumn -Key 'ApprovedTo' -Name 'Approved for'
            ) -ScriptBlock {
                # The last approval made in this session, so it is still here after leaving the page
                # and coming back. A table loads after the page is drawn, so it also fills the line
                # above it (a page Load event runs too early to reach either).
                $last = $WebEvent.Session.Data.RingResult
                if ($last) {
                    Update-PodeWebText -Id 'ring_result_when' -Value ("Approved $($last.When). $($last.Installs)" -replace ' $', '')
                    $last.Rows
                }
            }
        )
        New-PodeWebModal -Name 'ConfirmRing' -DisplayName 'Approve updates' -SubmitText 'Approve' -Content @(
            New-PodeWebText -Value 'Approve the updates that passed for the next rings? The gate is checked again, so the result may differ slightly from the preview.'
        ) -ScriptBlock {
            $user = Resolve-CassiniUser -AuthUser $WebEvent.Auth.User
            try {
                $rows = Invoke-CassiniRingApproval -Config (Get-PodeState -Name 'Config') -Preview $WebEvent.Session.Data.RingPreview -PreviewId $WebEvent.Data.Value -User $user -Confirm:$false
                # Last approval lists only what was actually approved; held updates stay in the preview.
                $approvedRows = @($rows | Where-Object ApprovedTo)
                $approved = $approvedRows.Count
                if ($approved -gt 0) {
                    # Kept in the session so the result is still here after leaving the page and coming back.
                    # A run that approved nothing leaves the previous last approval in place.
                    $approvedAt = Get-Date
                    $installs = try { Format-CassiniInstallTime -Schedule (Get-PodeState -Name 'Schedule') -After $approvedAt } catch { '' }
                    $WebEvent.Session.Data.RingResult = @{
                        When     = '{0:yyyy-MM-dd HH:mm} by {1}' -f $approvedAt, $user
                        Installs = $installs
                        Rows     = $approvedRows
                    }
                    $last = $WebEvent.Session.Data.RingResult
                    Update-PodeWebText -Id 'ring_result_when' -Value ("Approved $($last.When). $($last.Installs)" -replace ' $', '')
                    Update-PodeWebTable -Name 'RingResult' -Data $approvedRows
                }

                # The preview keeps only what is still pending; what was approved is under Last approval.
                $pending = @(Select-CassiniPendingRow -PreviewRow $WebEvent.Session.Data.RingPreviewRows -ApprovalRow $rows)
                if ($pending.Count -gt 0) {
                    Update-PodeWebText -Id 'ring_summary' -Value ('Approved {0}. Still pending: {1}, shown below. Preview again once more Pilot computers have installed them, or use Force for an out-of-band update.' -f $approved, $pending.Count)
                    Update-PodeWebTable -Name 'RingPreview' -Data $pending
                }
                else {
                    Update-PodeWebText -Id 'ring_summary' -Value "Approved $approved. Nothing from this preview is still pending."
                    Clear-PodeWebTable -Name 'RingPreview'
                }
                Show-PodeWebToast -Title 'Rings' -Message "Approved $approved update(s). The replica copies them on its next sync."
            }
            catch {
                Show-PodeWebToast -Title 'Approval not run' -Message $_.Exception.Message -Duration 15000
            }
            $WebEvent.Session.Data.Remove('RingPreview')
            $WebEvent.Session.Data.Remove('RingPreviewRows')
            Disable-PodeWebButton -Name 'ApproveRing'
            Hide-PodeWebModal
        }
    )

    # ---------------------------------------------------------------- Decline
    Add-PodeWebPage -Name 'Decline' -DisplayName 'Decline an update' -Index 3 -Icon 'cancel' -Content @(
        New-PodeWebCard -Name 'Lookup' -Content @(
            New-PodeWebParagraph -Value 'For an update Pilot found bad. Looks the KB up on the upstream (every product and architecture variant, exact KB only); nothing is declined until you confirm. The replica copies the decline on its next sync.'
            New-PodeWebForm -Name 'KbLookup' -SubmitText 'Look up' -Content @(
                New-PodeWebTextbox -Name 'Kb' -DisplayName 'KB number' -Placeholder 'KB5001234' -Required
            ) -ScriptBlock {
                $kb = "$($WebEvent.Data.Kb)".Trim()
                if ($kb -notmatch '^(KB)?\d+$') {
                    Show-PodeWebToast -Title 'Check the KB' -Message 'Enter a KB number such as KB5001234.'
                    return
                }

                try {
                    $result = Find-CassiniUpdate -Config (Get-PodeState -Name 'Config') -Kb $kb
                }
                catch {
                    $WebEvent.Session.Data.Remove('DeclinePreview')
                    Disable-PodeWebButton -Name 'DeclineKb'
                    Show-PodeWebToast -Title 'Lookup failed' -Message $_.Exception.Message -Duration 15000
                    return
                }

                $WebEvent.Session.Data.DeclinePreview = $result.Preview
                $text = if ($result.NotFound) {
                    "No update for $($result.Kb) on the upstream. Check it synced (classification Updates is not synced by default)."
                }
                else {
                    '{0}: {1} update(s), {2} to decline.' -f $result.Kb, $result.Rows.Count, $result.ToDecline
                }
                Update-PodeWebText -Id 'kb_summary' -Value $text
                Update-PodeWebTable -Name 'KbMatches' -Data $result.Rows
                if ($result.ToDecline -gt 0) { Enable-PodeWebButton -Name 'DeclineKb' } else { Disable-PodeWebButton -Name 'DeclineKb' }
            }
        )
        New-PodeWebCard -Name 'Matches' -Content @(
            New-PodeWebText -Id 'kb_summary' -Value 'Look up a KB to see what would be declined.'
            New-PodeWebTable -Name 'KbMatches' -DisplayName 'Matching updates' -Compact -NoExport -Columns @(
                Initialize-PodeWebTableColumn -Key 'Kb' -Name 'KB'
                Initialize-PodeWebTableColumn -Key 'OnConfirm' -Name 'On confirm'
            )
            New-PodeWebButton -Name 'DeclineKb' -DisplayName 'Decline' -Icon 'cancel' -Colour Red -Disabled -ScriptBlock {
                $preview = $WebEvent.Session.Data.DeclinePreview
                $id = if ($preview -and $preview.Kind -eq 'Decline') { $preview.Id } else { '' }
                $kb = if ($preview -and $preview.Kind -eq 'Decline') { $preview.Parameters.Kb } else { 'the update' }
                Show-PodeWebModal -Name 'ConfirmDecline' -DataValue $id -Actions @(
                    Update-PodeWebText -Id 'decline_kb' -Value $kb
                )
            }
        )
        New-PodeWebCard -Name 'Declined' -Content @(
            New-PodeWebTable -Name 'DeclineResult' -DisplayName 'What was declined' -Compact -Columns @(
                Initialize-PodeWebTableColumn -Key 'Kb' -Name 'KB'
                Initialize-PodeWebTableColumn -Key 'Action' -Name 'Result'
                Initialize-PodeWebTableColumn -Key 'NextStep' -Name 'Next step'
            )
        )
        New-PodeWebModal -Name 'ConfirmDecline' -DisplayName 'Decline update' -SubmitText 'Decline' -Content @(
            New-PodeWebText -Value 'Decline every update for '
            New-PodeWebText -Id 'decline_kb'
            New-PodeWebText -Value ' on the upstream? Machines that already installed it keep it until you remove it with DISM (WSUS README, section 8).'
        ) -ScriptBlock {
            $user = Resolve-CassiniUser -AuthUser $WebEvent.Auth.User
            try {
                $rows = Invoke-CassiniDecline -Config (Get-PodeState -Name 'Config') -Preview $WebEvent.Session.Data.DeclinePreview -PreviewId $WebEvent.Data.Value -User $user -Confirm:$false
                Update-PodeWebTable -Name 'DeclineResult' -Data @($rows | Select-Object -Property Kb, Update, Action, NextStep)
                $declined = @($rows | Where-Object Action -eq 'Declined').Count
                Show-PodeWebToast -Title 'Decline' -Message "Declined $declined update(s)."
            }
            catch {
                Show-PodeWebToast -Title 'Decline not run' -Message $_.Exception.Message -Duration 15000
            }
            $WebEvent.Session.Data.Remove('DeclinePreview')
            Disable-PodeWebButton -Name 'DeclineKb'
            Hide-PodeWebModal
        }
    )

    # ---------------------------------------------------------------- Audit
    Add-PodeWebPage -Name 'Audit' -Index 4 -Icon 'clipboard-text-clock' -Content @(
        New-PodeWebCard -Name 'Changes' -DisplayName 'Changes made through the portal' -Content @(
            New-PodeWebParagraph -Value 'Changes run as the portal service account, so WSUS only sees that account. This log records who confirmed each one. Newest first.'
            New-PodeWebTable -Name 'AuditLog' -DisplayName 'Audit log' -Compact -Paginate -PageSize 25 -ScriptBlock {
                Get-CassiniAuditLog -Config (Get-PodeState -Name 'Config') -Last 200 |
                    Select-Object -Property Time, User, Action, Server, Outcome, Detail
            }
        )
    )
}

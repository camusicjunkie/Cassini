<#
.SYNOPSIS
    Starts the Portcullis WSUS admin portal (Pode + Pode.Web).

.DESCRIPTION
    Four pages:
      Status   Both nodes from Get-WsusNodeStatus, refreshed every minute; start a sync on either node.
      Rings    Preview the Approve-WsusRing gate, then confirm to approve what passed.
      Decline  Look up a KB on the upstream, then confirm to decline it.
      Audit    The newest changes made through the portal, with who confirmed them.

    Every change is a two-step preview then confirm. The confirm step runs the parameters stored
    with the preview in the user's session (never values posted by the browser) and is refused once
    the preview is older than PreviewMaxAgeMinutes. Every change is written to the audit log.

    Run under IIS with Windows Authentication (docs/hosting-iis.md); only members of AdminGroup get
    in. Authentication = None in the configuration is for local development: it refuses to start
    under IIS, and listens on localhost only.

    The logic lives in the Portcullis module (src/Portcullis); this file is only the web layout.

.EXAMPLE
    ./server.ps1 -ConfigPath ./config/portcullis.psd1
#>
#Requires -Version 5.1
[CmdletBinding()]
param (
    # Portal configuration file (see config/portcullis.example.psd1).
    [string] $ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'config\portcullis.psd1')
)

$ErrorActionPreference = 'Stop'

$portcullisManifest = Join-Path -Path $PSScriptRoot -ChildPath 'src\Portcullis\Portcullis.psd1'
# Portcullis's manifest brings in the pinned Pode and Pode.Web; a missing or wrong version fails here.
Import-Module -Name WSUS
Import-Module -Name $portcullisManifest -Force
$config = Get-PortcullisConfig -Path $ConfigPath

Start-PodeServer -RootPath $PSScriptRoot -ScriptBlock {
    # Route and element scriptblocks run in their own runspaces: give them the modules and config.
    Import-PodeModule -Name WSUS
    Import-PodeModule -Path $portcullisManifest
    Set-PodeState -Name 'Config' -Value $config

    New-PodeLogFileMethod -Name 'portcullis_errors' | Enable-PodeLogErrorType

    if ($config.Authentication -eq 'None' -and (Test-PodeIsIIS)) {
        throw 'Authentication = None is for local development and is refused under IIS. Set Authentication = IIS.'
    }
    # Under IIS, Pode replaces this endpoint with the one IIS assigns.
    Add-PodeEndpoint -Address localhost -Port $config.ListenPort -Protocol Http

    Enable-PodeSessionMiddleware -Duration 1800 -Extend
    Initialize-PodeWebTemplates -Title $config.Title -Theme Auto -NoPageFilter
    # Pode.Web breaks table cells mid-word; keep words whole and let wide tables scroll instead.
    Import-PodeWebStylesheet -Url '/portcullis.css'

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
                Get-PortcullisNodeStatus -Config (Get-PodeState -Name 'Config') |
                    Select-Object -Property Node, Server, Role, Sync, LastSync, LastSyncResult, Updates, Approved, Declined, DownloadPendingMB, DownloadFailed, Note
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
            $user = Resolve-PortcullisUser -AuthUser $WebEvent.Auth.User
            try {
                $result = Invoke-PortcullisSync -Config (Get-PodeState -Name 'Config') -Node $WebEvent.Data.Value -User $user -Confirm:$false
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

    # ---------------------------------------------------------------- Rings
    Add-PodeWebPage -Name 'Rings' -DisplayName 'Promote rings' -Index 1 -Icon 'stairs-up' -Content @(
        New-PodeWebCard -Name 'Gate' -DisplayName 'Gate settings' -Content @(
            New-PodeWebParagraph -Value 'Previews Approve-WsusRing on the upstream: Critical and Security updates approved for Pilot, checked against the gate. Nothing is approved until you confirm. Monthly cycle: preview Monday of week 2, approve Tuesday.'
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
                    $result = Get-PortcullisRingPreview -Config (Get-PodeState -Name 'Config') -MinimumSoakDays $soak -MinimumInstalledPercent $percent -Force:($WebEvent.Data.Force -eq 'true')
                }
                catch {
                    $WebEvent.Session.Data.Remove('RingPreview')
                    Disable-PodeWebButton -Name 'ApproveRing'
                    Show-PodeWebToast -Title 'Preview failed' -Message $_.Exception.Message -Duration 15000
                    return
                }

                $WebEvent.Session.Data.RingPreview = $result.Preview
                $summary = $result.Summary
                $text = '{0} candidate update(s): {1} would be approved ({2} forced), {3} held.' -f $summary.Candidates, $summary.Approvable, $summary.Forced, $summary.Held
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
        New-PodeWebCard -Name 'Result' -Content @(
            New-PodeWebTable -Name 'RingResult' -DisplayName 'What was approved' -Compact -Columns @(
                Initialize-PodeWebTableColumn -Key 'Kb' -Name 'KB'
                Initialize-PodeWebTableColumn -Key 'ApprovedTo' -Name 'Approved for'
            )
        )
        New-PodeWebModal -Name 'ConfirmRing' -DisplayName 'Approve updates' -SubmitText 'Approve' -Content @(
            New-PodeWebText -Value 'Approve the updates that passed in the preview for the next rings? The gate is checked again now, so the result can differ slightly from the preview. Workstations install Wednesday and Servers Thursday, per the client GPO schedule.'
        ) -ScriptBlock {
            $user = Resolve-PortcullisUser -AuthUser $WebEvent.Auth.User
            try {
                $rows = Invoke-PortcullisRingApproval -Config (Get-PodeState -Name 'Config') -Preview $WebEvent.Session.Data.RingPreview -PreviewId $WebEvent.Data.Value -User $user -Confirm:$false
                $approved = @($rows | Where-Object ApprovedTo).Count
                Update-PodeWebTable -Name 'RingResult' -Data @($rows)
                Show-PodeWebToast -Title 'Rings' -Message "$approved update(s) approved. The replica copies them on its next sync."
            }
            catch {
                Show-PodeWebToast -Title 'Approval not run' -Message $_.Exception.Message -Duration 15000
            }
            $WebEvent.Session.Data.Remove('RingPreview')
            Disable-PodeWebButton -Name 'ApproveRing'
            Hide-PodeWebModal
        }
    )

    # ---------------------------------------------------------------- Decline
    Add-PodeWebPage -Name 'Decline' -DisplayName 'Decline an update' -Index 2 -Icon 'cancel' -Content @(
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
                    $result = Find-PortcullisUpdate -Config (Get-PodeState -Name 'Config') -Kb $kb
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
            $user = Resolve-PortcullisUser -AuthUser $WebEvent.Auth.User
            try {
                $rows = Invoke-PortcullisDecline -Config (Get-PodeState -Name 'Config') -Preview $WebEvent.Session.Data.DeclinePreview -PreviewId $WebEvent.Data.Value -User $user -Confirm:$false
                Update-PodeWebTable -Name 'DeclineResult' -Data @($rows | Select-Object -Property Kb, Update, Action, NextStep)
                $declined = @($rows | Where-Object Action -eq 'Declined').Count
                Show-PodeWebToast -Title 'Decline' -Message "$declined update(s) declined."
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
    Add-PodeWebPage -Name 'Audit' -Index 3 -Icon 'clipboard-text-clock' -Content @(
        New-PodeWebCard -Name 'Changes' -DisplayName 'Changes made through the portal' -Content @(
            New-PodeWebParagraph -Value 'Changes run as the portal service account, so WSUS only sees that account. This log records who confirmed each one. Newest first.'
            New-PodeWebTable -Name 'AuditLog' -DisplayName 'Audit log' -Compact -Paginate -PageSize 25 -ScriptBlock {
                Get-PortcullisAuditLog -Config (Get-PodeState -Name 'Config') -Last 200 |
                    Select-Object -Property Time, User, Action, Server, Outcome, Detail
            }
        )
    )
}

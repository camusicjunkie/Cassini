BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-PortcullisTestEnvironment }

Describe 'Get-PortcullisNodeStatus' {
    BeforeAll {
        function New-Status {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
                Justification = 'Builds a test object; nothing changes.')]
            param ([string] $Server, [string] $Role, [int] $Approved = 300)
            [PSCustomObject] @{
                Server              = $Server
                Role                = $Role
                LastSyncTime        = [datetime] '2026-10-30 02:00'
                LastSyncResult      = 'Succeeded'
                LastSyncError       = $null
                SyncStatus          = 'NotProcessing'
                SyncPhase           = $null
                SyncProcessedItems  = $null
                SyncTotalItems      = $null
                UpdateCount         = 4000
                ApprovedUpdateCount = $Approved
                DeclinedUpdateCount = 3000
                DownloadPendingMB   = 0
                DownloadFailedCount = 0
            }
        }
    }

    BeforeEach {
        $script:config = New-TestConfig
    }

    It 'returns one row per node, upstream first, with the configured port' {
        Mock -ModuleName Portcullis Get-WsusNodeStatus { New-Status -Server $WsusServer[0] -Role $(if ($WsusServer[0] -match '01') { 'Upstream' } else { 'Replica' }) }

        $rows = @(Get-PortcullisNodeStatus -Config $script:config)

        $rows.Count | Should -Be 2
        $rows[0].Node | Should -Be 'Upstream'
        $rows[0].Server | Should -Be 'wsus01.test.local'
        $rows[0].LastSync | Should -Be '2026-10-30 02:00'
        $rows[0].Sync | Should -Be 'Idle'
        $rows[1].Node | Should -Be 'Replica'
        $rows | ForEach-Object { $_.Note | Should -BeNullOrEmpty }
        Should -Invoke -ModuleName Portcullis Get-WsusNodeStatus -Times 2 -Exactly -ParameterFilter { $Port -eq 8531 }
    }

    It 'shows only the upstream when no replica is configured' {
        $script:config = New-TestConfig -Value @{ ReplicaServer = '' }
        Mock -ModuleName Portcullis Get-WsusNodeStatus { New-Status -Server $WsusServer[0] -Role 'Upstream' }

        @(Get-PortcullisNodeStatus -Config $script:config).Count | Should -Be 1
    }

    It 'keeps a row for an unreachable node, with the error' {
        Mock -ModuleName Portcullis Get-WsusNodeStatus {
            if ($WsusServer[0] -match '02') {
                # The real function honours the caller's -ErrorAction; the mock body runs under the
                # runner's preference (Stop in build.ps1), so say it here.
                Write-Error -Message 'Cannot connect to wsus02 on port 8531.' -ErrorAction SilentlyContinue
                return
            }
            New-Status -Server $WsusServer[0] -Role 'Upstream'
        }

        $rows = @(Get-PortcullisNodeStatus -Config $script:config)

        $rows.Count | Should -Be 2
        $rows[1].Reachable | Should -BeFalse
        $rows[1].Note | Should -BeLike 'Unreachable: Cannot connect to wsus02*'
    }

    It 'shows sync progress while a sync runs' {
        Mock -ModuleName Portcullis Get-WsusNodeStatus {
            $status = New-Status -Server $WsusServer[0] -Role $(if ($WsusServer[0] -match '01') { 'Upstream' } else { 'Replica' })
            $status.SyncStatus = 'Running'
            $status.SyncPhase = 'Updates'
            $status.SyncProcessedItems = 40
            $status.SyncTotalItems = 100
            $status
        }

        (Get-PortcullisNodeStatus -Config $script:config)[0].Sync | Should -Be 'Updates (40 of 100)'
    }

    It 'joins a failed sync result with its error' {
        Mock -ModuleName Portcullis Get-WsusNodeStatus {
            $status = New-Status -Server $WsusServer[0] -Role $(if ($WsusServer[0] -match '01') { 'Upstream' } else { 'Replica' })
            $status.LastSyncResult = 'Failed'
            $status.LastSyncError = 'proxy refused'
            $status
        }

        (Get-PortcullisNodeStatus -Config $script:config)[0].LastSyncResult | Should -Be 'Failed: proxy refused'
    }

    It 'flags a node whose role differs from its configured role' {
        Mock -ModuleName Portcullis Get-WsusNodeStatus { New-Status -Server $WsusServer[0] -Role 'Upstream' }

        (Get-PortcullisNodeStatus -Config $script:config)[1].Note | Should -BeLike 'Configured as Replica but reports Upstream*'
    }

    It 'notes a replica whose counts differ from the upstream' {
        Mock -ModuleName Portcullis Get-WsusNodeStatus {
            if ($WsusServer[0] -match '01') { New-Status -Server $WsusServer[0] -Role 'Upstream' -Approved 310 }
            else { New-Status -Server $WsusServer[0] -Role 'Replica' -Approved 300 }
        }

        $rows = @(Get-PortcullisNodeStatus -Config $script:config)

        $rows[0].Note | Should -BeNullOrEmpty
        $rows[1].Note | Should -BeLike '*Approved 300 vs 310*'
    }
}

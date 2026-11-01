BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-CassiniTestEnvironment }

Describe 'Invoke-CassiniRingApproval' {
    BeforeEach {
        $script:config = New-TestConfig
        $script:preview = New-CassiniPreview -Kind Ring -Parameters @{ MinimumSoakDays = 1; MinimumInstalledPercent = 50; Force = $true }
        Mock -ModuleName Cassini Approve-WsusRing {
            [PSCustomObject] @{ Update = 'CU'; Kb = '5001'; Gate = 'Forced'; Reason = @('soak not finished'); ApprovedTo = @('Workstations', 'Servers') }
            [PSCustomObject] @{ Update = 'SSU'; Kb = '5002'; Gate = 'Passed'; Reason = @(); ApprovedTo = @() }
        }
    }

    It 'runs Approve-WsusRing with the previewed settings, not -WhatIf' {
        $null = Invoke-CassiniRingApproval -Config $script:config -Preview $script:preview -PreviewId $script:preview.Id -User 'TEST\jdoe'

        Should -Invoke -ModuleName Cassini Approve-WsusRing -Times 1 -Exactly -ParameterFilter {
            $MinimumSoakDays -eq 1 -and $MinimumInstalledPercent -eq 50 -and $Force -and
            $WsusServer -eq 'wsus01.test.local' -and -not $WhatIfPreference
        }
    }

    It 'returns what was approved' {
        $rows = @(Invoke-CassiniRingApproval -Config $script:config -Preview $script:preview -PreviewId $script:preview.Id -User 'TEST\jdoe')

        $rows[0].Kb | Should -Be 'KB5001'
        $rows[0].ApprovedTo | Should -Be 'Workstations, Servers'
        $rows[0].Reason | Should -BeExactly 'Soak not finished'
        $rows[1].ApprovedTo | Should -Be ''
    }

    It 'audits the user, settings and approvals' {
        $null = Invoke-CassiniRingApproval -Config $script:config -Preview $script:preview -PreviewId $script:preview.Id -User 'TEST\jdoe' -WarningAction SilentlyContinue

        $entry = Get-TestAuditEntry -Config $script:config
        $entry.User | Should -Be 'TEST\jdoe'
        $entry.Action | Should -Be 'ApproveRing'
        $entry.Server | Should -Be 'wsus01.test.local'
        $entry.Outcome | Should -Be 'Succeeded'
        $entry.Detail.Approved | Should -Be 'KB5001'
        $entry.Detail.Parameters.Force | Should -BeTrue
    }

    It 'audits a failure and rethrows it' {
        Mock -ModuleName Cassini Approve-WsusRing { throw 'Run this on the upstream.' }

        { Invoke-CassiniRingApproval -Config $script:config -Preview $script:preview -PreviewId $script:preview.Id -User 'TEST\jdoe' -WarningAction SilentlyContinue } |
            Should -Throw 'Run this on the upstream.'

        $entry = Get-TestAuditEntry -Config $script:config
        $entry.Outcome | Should -Be 'Failed'
        $entry.Detail.Error | Should -Be 'Run this on the upstream.'
    }

    It 'refuses <Case> without calling WSUS' -ForEach @(
        @{ Case = 'no preview'; Make = { $null }; Id = 'x'; Message = '*no preview*' }
        @{ Case = 'a decline preview'; Make = { New-CassiniPreview -Kind Decline -Parameters @{ Kb = 'KB1' } }; Id = $null; Message = '*Decline preview*' }
        @{ Case = 'another preview id'; Make = { New-CassiniPreview -Kind Ring -Parameters @{} }; Id = 'other'; Message = '*older preview*' }
    ) {
        $stored = & $Make
        $id = if ($null -ne $Id) { $Id } else { $stored.Id }

        { Invoke-CassiniRingApproval -Config $script:config -Preview $stored -PreviewId $id -User 'TEST\jdoe' } | Should -Throw $Message
        Should -Invoke -ModuleName Cassini Approve-WsusRing -Times 0
        Get-TestAuditEntry -Config $script:config | Should -BeNullOrEmpty
    }

    It 'does nothing under -WhatIf' {
        $null = Invoke-CassiniRingApproval -Config $script:config -Preview $script:preview -PreviewId $script:preview.Id -User 'TEST\jdoe' -WhatIf

        Should -Invoke -ModuleName Cassini Approve-WsusRing -Times 0
    }
}

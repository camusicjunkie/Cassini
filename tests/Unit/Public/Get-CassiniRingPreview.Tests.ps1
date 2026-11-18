BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-CassiniTestEnvironment }

Describe 'Get-CassiniRingPreview' {
    BeforeEach {
        $script:config = New-TestConfig
        Mock -ModuleName Cassini Approve-WsusRing {
            [PSCustomObject] @{ Update = 'CU'; Kb = '5001'; Installed = 18; Needed = 19; Percent = 94; Failed = 0; Gate = 'Passed'; Reason = @(); ApprovedTo = @() }
            [PSCustomObject] @{ Update = 'Edge'; Kb = '5002, 5003'; Installed = 5; Needed = 19; Percent = 26; Failed = 1; Gate = 'Held'; Reason = @('only 26% installed in Pilot', '1 failed in Pilot'); ApprovedTo = @() }
        }
    }

    It 'runs Approve-WsusRing with -WhatIf against the upstream' {
        $null = Get-CassiniRingPreview -Config $script:config -MinimumSoakDays 3 -MinimumInstalledPercent 80

        Should -Invoke -ModuleName Cassini Approve-WsusRing -Times 1 -Exactly -ParameterFilter {
            $WhatIf
        }
        Should -Invoke -ModuleName Cassini Approve-WsusRing -Times 1 -Exactly -ParameterFilter {
            $WsusServer -eq 'wsus01.test.local' -and $Port -eq 8531 -and $MinimumSoakDays -eq 3 -and $MinimumInstalledPercent -eq 80 -and -not $Force
        }
    }

    It 'flattens rows for the web table' {
        $rows = (Get-CassiniRingPreview -Config $script:config).Rows

        $rows[0].Kb | Should -Be 'KB5001'
        $rows[0].Installed | Should -Be '18 of 19 (94%)'
        $rows[0].OnConfirm | Should -Be 'Approve'
        $rows[1].Kb | Should -Be 'KB5002, KB5003'
        $rows[1].Reason | Should -BeExactly 'Only 26% installed in Pilot; 1 failed in Pilot'
        $rows[1].OnConfirm | Should -Be 'Hold'
    }

    It 'adds the clients that have not reported when there are any' {
        Mock -ModuleName Cassini Approve-WsusRing {
            [PSCustomObject] @{ Update = 'CU'; Kb = '5001'; Installed = 17; Needed = 19; Unknown = 3; Percent = 77; Failed = 0; Gate = 'Held'; Reason = @('only 77% installed in Pilot (3 not reported)'); ApprovedTo = @() }
            [PSCustomObject] @{ Update = 'SSU'; Kb = '5004'; Installed = 3; Needed = 3; Unknown = 0; Percent = 100; Failed = 0; Gate = 'Passed'; Reason = @(); ApprovedTo = @() }
        }

        $rows = (Get-CassiniRingPreview -Config $script:config).Rows

        $rows[0].Installed | Should -Be '17 of 19 (77%), 3 not reporting'
        $rows[1].Installed | Should -Be '3 of 3 (100%)'
    }

    It 'counts approvable and held updates' {
        $summary = (Get-CassiniRingPreview -Config $script:config).Summary

        $summary.Candidates | Should -Be 2
        $summary.Approvable | Should -Be 1
        $summary.Held | Should -Be 1
        $summary.Forced | Should -Be 0
    }

    It 'records the gate settings in a Ring preview' {
        $script:preview = (Get-CassiniRingPreview -Config $script:config -MinimumSoakDays 1 -Force).Preview

        $script:preview.Kind | Should -Be 'Ring'
        $script:preview.Parameters.MinimumSoakDays | Should -Be 1
        $script:preview.Parameters.MinimumInstalledPercent | Should -Be 90
        $script:preview.Parameters.Force | Should -BeTrue
    }

    It 'returns empty rows when nothing is a candidate' {
        Mock -ModuleName Cassini Approve-WsusRing { }

        $result = Get-CassiniRingPreview -Config $script:config

        @($result.Rows).Count | Should -Be 0
        $result.Summary.Approvable | Should -Be 0
    }
}

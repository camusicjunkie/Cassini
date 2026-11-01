BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-CassiniTestEnvironment }

Describe 'Find-CassiniUpdate' {
    BeforeEach {
        $script:config = New-TestConfig
        Mock -ModuleName Cassini Get-WsusServer {
            $server = [PSCustomObject] @{}
            $server | Add-Member -MemberType ScriptMethod -Name SearchUpdates -Value {
                [PSCustomObject] @{ Title = 'Edge x64'; KnowledgebaseArticles = @('5001234'); ArrivalDate = [datetime] '2026-10-20 08:00'; IsDeclined = $false; IsSuperseded = $false }
                [PSCustomObject] @{ Title = 'Edge arm64'; KnowledgebaseArticles = @('5001234'); ArrivalDate = [datetime] '2026-10-20 08:00'; IsDeclined = $true; IsSuperseded = $false }
                [PSCustomObject] @{ Title = 'Look-alike'; KnowledgebaseArticles = @('50012345'); ArrivalDate = [datetime] '2026-10-20 08:00'; IsDeclined = $false; IsSuperseded = $false }
            }
            $server
        }
    }

    It 'connects to the upstream over SSL on the configured port' {
        $null = Find-CassiniUpdate -Config $script:config -Kb 'KB5001234'

        Should -Invoke -ModuleName Cassini Get-WsusServer -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'wsus01.test.local' -and $PortNumber -eq 8531 -and $UseSsl
        }
    }

    It 'keeps exact KB matches only' {
        $result = Find-CassiniUpdate -Config $script:config -Kb '5001234'

        $result.Kb | Should -Be 'KB5001234'
        @($result.Rows.Update) | Should -Be @('Edge x64', 'Edge arm64')
        $result.Rows[0].Arrived | Should -Be '2026-10-20 08:00'
    }

    It 'says which updates a confirm would decline' {
        $result = Find-CassiniUpdate -Config $script:config -Kb 'KB5001234'

        $result.ToDecline | Should -Be 1
        $result.Rows[0].OnConfirm | Should -Be 'Decline'
        $result.Rows[1].OnConfirm | Should -Be 'Already declined'
        $result.NotFound | Should -BeFalse
    }

    It 'records the KB in a Decline preview' {
        $script:preview = (Find-CassiniUpdate -Config $script:config -Kb ' kb5001234 '.ToUpper()).Preview

        $script:preview.Kind | Should -Be 'Decline'
        $script:preview.Parameters.Kb | Should -Be 'KB5001234'
    }

    It 'reports a KB with no update as NotFound' {
        $result = Find-CassiniUpdate -Config $script:config -Kb 'KB999'

        $result.NotFound | Should -BeTrue
        $result.ToDecline | Should -Be 0
    }

    It 'rejects text that is not a KB number' {
        { Find-CassiniUpdate -Config $script:config -Kb 'KB12; rm' } | Should -Throw
        Should -Invoke -ModuleName Cassini Get-WsusServer -Times 0
    }
}

BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-CassiniTestEnvironment }

Describe 'Invoke-CassiniSync' {
    BeforeEach {
        $script:config = New-TestConfig
        Mock -ModuleName Cassini Start-WsusSync { [PSCustomObject] @{ Server = $WsusServer; Status = 'Started' } }
    }

    It 'starts a sync on the <Node> without waiting' -ForEach @(
        @{ Node = 'Upstream'; Server = 'wsus01.test.local' }
        @{ Node = 'Replica'; Server = 'wsus02.test.local' }
    ) {
        $result = Invoke-CassiniSync -Config $script:config -Node $Node -User 'TEST\jdoe' -WarningAction SilentlyContinue

        $result.Server | Should -Be $Server
        Should -Invoke -ModuleName Cassini Start-WsusSync -Times 1 -Exactly -ParameterFilter {
            $WsusServer -eq $Server -and -not $Wait -and -not $CategoryOnly
        }
        (Get-TestAuditEntry -Config $script:config).Server | Should -Be $Server
    }

    It 'throws when no replica is configured' {
        $script:config = New-TestConfig -Value @{ ReplicaServer = '' }

        { Invoke-CassiniSync -Config $script:config -Node Replica -User 'TEST\jdoe' } | Should -Throw '*No Replica is configured*'
        Should -Invoke -ModuleName Cassini Start-WsusSync -Times 0
    }

    It 'audits a failure and rethrows it' {
        Mock -ModuleName Cassini Start-WsusSync { throw 'unreachable' }

        { Invoke-CassiniSync -Config $script:config -Node Upstream -User 'TEST\jdoe' -WarningAction SilentlyContinue } | Should -Throw 'unreachable'
        (Get-TestAuditEntry -Config $script:config).Outcome | Should -Be 'Failed'
    }
}

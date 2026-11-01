BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-CassiniTestEnvironment }

Describe 'Assert-CassiniAuditSource' {
    It 'throws when the event log is required and the source is missing' {
        Mock -ModuleName Cassini Test-CassiniEventSource { $false }
        $config = New-TestConfig -Value @{ AuditEventLog = 'Required' }

        { Assert-CassiniAuditSource -Config $config } | Should -Throw '*New-EventLog -LogName Application -Source Cassini*'
    }

    It 'passes when the source is registered' {
        Mock -ModuleName Cassini Test-CassiniEventSource { $true }
        $config = New-TestConfig -Value @{ AuditEventLog = 'Required' }

        { Assert-CassiniAuditSource -Config $config } | Should -Not -Throw
    }

    It 'does not check when the event log is optional' {
        Mock -ModuleName Cassini Test-CassiniEventSource { $false }
        $config = New-TestConfig -Value @{ AuditEventLog = 'Optional' }

        { Assert-CassiniAuditSource -Config $config } | Should -Not -Throw
        Should -Invoke -ModuleName Cassini Test-CassiniEventSource -Times 0
    }
}

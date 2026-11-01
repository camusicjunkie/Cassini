BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-PortcullisTestEnvironment }

Describe 'Assert-PortcullisAuditSource' {
    It 'throws when the event log is required and the source is missing' {
        Mock -ModuleName Portcullis Test-PortcullisEventSource { $false }
        $config = New-TestConfig -Value @{ AuditEventLog = 'Required' }

        { Assert-PortcullisAuditSource -Config $config } | Should -Throw '*New-EventLog -LogName Application -Source Portcullis*'
    }

    It 'passes when the source is registered' {
        Mock -ModuleName Portcullis Test-PortcullisEventSource { $true }
        $config = New-TestConfig -Value @{ AuditEventLog = 'Required' }

        { Assert-PortcullisAuditSource -Config $config } | Should -Not -Throw
    }

    It 'does not check when the event log is optional' {
        Mock -ModuleName Portcullis Test-PortcullisEventSource { $false }
        $config = New-TestConfig -Value @{ AuditEventLog = 'Optional' }

        { Assert-PortcullisAuditSource -Config $config } | Should -Not -Throw
        Should -Invoke -ModuleName Portcullis Test-PortcullisEventSource -Times 0
    }
}

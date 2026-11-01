BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-CassiniTestEnvironment }

Describe 'Get-CassiniAuditLog' {
    BeforeEach {
        $script:config = New-TestConfig
    }

    It 'returns nothing before the first change' {
        Get-CassiniAuditLog -Config $script:config | Should -BeNullOrEmpty
    }

    It 'returns entries newest first, limited to -Last, skipping bad lines' {
        $null = New-Item -ItemType Directory -Path (Split-Path -Path $script:config.AuditLogPath) -Force
        @(
            '{"Time":"2026-10-01T10:00:00Z","User":"A","Action":"StartSync","Server":"s","Outcome":"Succeeded","Detail":{"Status":"Started"}}'
            'not json'
            '{"Time":"2026-10-02T10:00:00Z","User":"B","Action":"DeclineUpdate","Server":"s","Outcome":"Failed","Detail":{"Kb":"KB1"}}'
            '{"Time":"2026-10-03T10:00:00Z","User":"C","Action":"ApproveRing","Server":"s","Outcome":"Succeeded","Detail":{}}'
        ) | Set-Content -LiteralPath $script:config.AuditLogPath -Encoding UTF8

        $entries = @(Get-CassiniAuditLog -Config $script:config -Last 3 -WarningVariable warnings -WarningAction SilentlyContinue)

        @($entries.User) | Should -Be @('C', 'B')
        $entries[1].Detail | Should -Be '{"Kb":"KB1"}'
        $warnings.Count | Should -Be 1
    }
}

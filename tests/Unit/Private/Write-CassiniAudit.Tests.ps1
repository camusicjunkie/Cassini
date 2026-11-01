BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-CassiniTestEnvironment }

# Shared helper: every change writes through it. The Invoke-* tests check what they record.
Describe 'Write-CassiniAudit' {
    It 'creates the folder and appends one JSON line per call' {
        $config = New-TestConfig
        InModuleScope Cassini -Parameters @{ Config = $config } {
            Write-CassiniAudit -Config $Config -User 'TEST\a' -Action 'StartSync' -Server 's1' -Outcome Succeeded -WarningAction SilentlyContinue
            Write-CassiniAudit -Config $Config -User 'TEST\b' -Action 'DeclineUpdate' -Server 's1' -Outcome Failed -Detail @{ Kb = 'KB1' } -WarningAction SilentlyContinue
        }

        $lines = @(Get-Content -LiteralPath $config.AuditLogPath)
        $lines.Count | Should -Be 2
        $second = $lines[1] | ConvertFrom-Json
        $second.User | Should -Be 'TEST\b'
        $second.Outcome | Should -Be 'Failed'
        $second.Detail.Kb | Should -Be 'KB1'
    }

    It 'throws when the file cannot be written, so no change goes unrecorded' {
        $blocker = Join-Path -Path $TestDrive -ChildPath 'blocker'
        Set-Content -Path $blocker -Value 'a file, not a folder'
        $config = New-TestConfig -Value @{ AuditLogPath = (Join-Path -Path $blocker -ChildPath 'audit.log') }

        InModuleScope Cassini -Parameters @{ Config = $config } {
            { Write-CassiniAudit -Config $Config -User 'u' -Action 'StartSync' -Server 's' -Outcome Succeeded -WarningAction SilentlyContinue -ErrorAction Stop } | Should -Throw
        }
    }
}

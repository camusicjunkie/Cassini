BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-CassiniTestEnvironment }

Describe 'Invoke-CassiniDecline' {
    BeforeEach {
        $script:config = New-TestConfig
        $script:preview = New-CassiniPreview -Kind Decline -Parameters @{ Kb = 'KB5001234' }
        Mock -ModuleName Cassini Deny-WsusUpdate {
            [PSCustomObject] @{ Kb = 'KB5001234'; Update = 'Edge x64'; Action = 'Declined'; NextStep = 'DISM' }
            [PSCustomObject] @{ Kb = 'KB5001234'; Update = 'Edge arm64'; Action = 'AlreadyDeclined'; NextStep = 'DISM' }
        }
    }

    It 'declines the previewed KB on the upstream' {
        $rows = @(Invoke-CassiniDecline -Config $script:config -Preview $script:preview -PreviewId $script:preview.Id -User 'TEST\jdoe')

        $rows.Count | Should -Be 2
        Should -Invoke -ModuleName Cassini Deny-WsusUpdate -Times 1 -Exactly -ParameterFilter {
            $Kb -eq 'KB5001234' -and $WsusServer -eq 'wsus01.test.local' -and $Port -eq 8531
        }
    }

    It 'audits the counts' {
        $null = Invoke-CassiniDecline -Config $script:config -Preview $script:preview -PreviewId $script:preview.Id -User 'TEST\jdoe' -WarningAction SilentlyContinue

        $entry = Get-TestAuditEntry -Config $script:config
        $entry.Action | Should -Be 'DeclineUpdate'
        $entry.Outcome | Should -Be 'Succeeded'
        $entry.Detail.Kb | Should -Be 'KB5001234'
        $entry.Detail.Declined | Should -Be 1
        $entry.Detail.Already | Should -Be 1
    }

    It 'treats a non-terminating error from Deny-WsusUpdate as a failure' {
        Mock -ModuleName Cassini Deny-WsusUpdate { Write-Error -Message 'No update found for KB5001234.' -ErrorAction SilentlyContinue }

        { Invoke-CassiniDecline -Config $script:config -Preview $script:preview -PreviewId $script:preview.Id -User 'TEST\jdoe' -WarningAction SilentlyContinue } |
            Should -Throw '*No update found*'
        (Get-TestAuditEntry -Config $script:config).Outcome | Should -Be 'Failed'
    }

    It 'audits a terminating failure and rethrows it' {
        Mock -ModuleName Cassini Deny-WsusUpdate { throw 'Not the upstream.' }

        { Invoke-CassiniDecline -Config $script:config -Preview $script:preview -PreviewId $script:preview.Id -User 'TEST\jdoe' -WarningAction SilentlyContinue } |
            Should -Throw 'Not the upstream.'
        (Get-TestAuditEntry -Config $script:config).Detail.Error | Should -Be 'Not the upstream.'
    }

    It 'refuses a ring preview' {
        $ring = New-CassiniPreview -Kind Ring -Parameters @{}

        { Invoke-CassiniDecline -Config $script:config -Preview $ring -PreviewId $ring.Id -User 'TEST\jdoe' } | Should -Throw '*Ring preview*'
        Should -Invoke -ModuleName Cassini Deny-WsusUpdate -Times 0
    }
}

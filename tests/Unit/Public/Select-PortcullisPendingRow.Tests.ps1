BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-PortcullisTestEnvironment }

Describe 'Select-PortcullisPendingRow' {
    BeforeAll {
        $script:preview = @(
            [PSCustomObject] @{ Kb = 'KB1'; Update = 'CU x64'; Gate = 'Passed' }
            [PSCustomObject] @{ Kb = 'KB1'; Update = 'CU arm64'; Gate = 'Passed' }
            [PSCustomObject] @{ Kb = 'KB2'; Update = 'Edge'; Gate = 'Held' }
        )
    }

    It 'drops the updates that were approved and keeps the rest' {
        $approval = @(
            [PSCustomObject] @{ Update = 'CU x64'; ApprovedTo = 'Workstations, Servers' }
            [PSCustomObject] @{ Update = 'CU arm64'; ApprovedTo = '' }
            [PSCustomObject] @{ Update = 'Edge'; ApprovedTo = '' }
        )

        @((Select-PortcullisPendingRow -PreviewRow $script:preview -ApprovalRow $approval).Update) |
            Should -Be @('CU arm64', 'Edge')
    }

    It 'returns nothing when everything was approved' {
        $approval = $script:preview | ForEach-Object { [PSCustomObject] @{ Update = $_.Update; ApprovedTo = 'Servers' } }

        Select-PortcullisPendingRow -PreviewRow $script:preview -ApprovalRow $approval | Should -BeNullOrEmpty
    }

    It 'keeps every row when nothing was approved, or there is no result' {
        @(Select-PortcullisPendingRow -PreviewRow $script:preview -ApprovalRow @()).Count | Should -Be 3
        @(Select-PortcullisPendingRow -PreviewRow $script:preview -ApprovalRow $null).Count | Should -Be 3
    }

    It 'returns nothing when there was no preview' {
        Select-PortcullisPendingRow -PreviewRow $null -ApprovalRow @() | Should -BeNullOrEmpty
    }
}

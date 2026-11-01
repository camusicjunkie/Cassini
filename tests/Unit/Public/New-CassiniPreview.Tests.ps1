BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-CassiniTestEnvironment }

Describe 'New-CassiniPreview' {
    It 'records the kind, a unique id, the time and a copy of the parameters' {
        $parameters = @{ Kb = 'KB1' }
        $first = New-CassiniPreview -Kind Decline -Parameters $parameters
        $second = New-CassiniPreview -Kind Decline -Parameters $parameters
        $parameters.Kb = 'changed'

        $first.Kind | Should -Be 'Decline'
        $first.Id | Should -Not -Be $second.Id
        $first.Parameters.Kb | Should -Be 'KB1'
        [datetime]::Parse($first.CreatedUtc).ToUniversalTime() | Should -BeLessOrEqual ([datetime]::UtcNow)
    }

    It 'rejects an unknown kind' {
        { New-CassiniPreview -Kind Sync -Parameters @{} } | Should -Throw
    }
}

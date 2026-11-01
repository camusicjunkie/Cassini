BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-PortcullisTestEnvironment }

Describe 'New-PortcullisPreview' {
    It 'records the kind, a unique id, the time and a copy of the parameters' {
        $parameters = @{ Kb = 'KB1' }
        $first = New-PortcullisPreview -Kind Decline -Parameters $parameters
        $second = New-PortcullisPreview -Kind Decline -Parameters $parameters
        $parameters.Kb = 'changed'

        $first.Kind | Should -Be 'Decline'
        $first.Id | Should -Not -Be $second.Id
        $first.Parameters.Kb | Should -Be 'KB1'
        [datetime]::Parse($first.CreatedUtc).ToUniversalTime() | Should -BeLessOrEqual ([datetime]::UtcNow)
    }

    It 'rejects an unknown kind' {
        { New-PortcullisPreview -Kind Sync -Parameters @{} } | Should -Throw
    }
}

BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-CassiniTestEnvironment }

Describe 'Format-CassiniKb' {
    It 'formats <Value> as <Expected>' -ForEach @(
        @{ Value = '5001234'; Expected = 'KB5001234' }
        @{ Value = 'KB5001234'; Expected = 'KB5001234' }
        @{ Value = '5001, 5002'; Expected = 'KB5001, KB5002' }
        @{ Value = ''; Expected = '' }
    ) {
        InModuleScope Cassini -Parameters @{ Value = $Value; Expected = $Expected } {
            Format-CassiniKb -Value $Value | Should -Be $Expected
        }
    }
}

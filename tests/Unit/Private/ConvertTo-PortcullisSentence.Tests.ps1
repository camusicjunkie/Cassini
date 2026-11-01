BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-PortcullisTestEnvironment }

Describe 'ConvertTo-PortcullisSentence' {
    It 'turns <Text> into <Expected>' -ForEach @(
        @{ Text = 'only 63% installed in Pilot'; Expected = 'Only 63% installed in Pilot' }
        @{ Text = 'Already a sentence'; Expected = 'Already a sentence' }
        @{ Text = '  approved for Pilot on 2026-10-30'; Expected = 'Approved for Pilot on 2026-10-30' }
        @{ Text = '1 failed in Pilot'; Expected = '1 failed in Pilot' }
        @{ Text = ''; Expected = '' }
    ) {
        InModuleScope Portcullis -Parameters @{ Text = $Text; Expected = $Expected } {
            ConvertTo-PortcullisSentence -Text $Text | Should -BeExactly $Expected
        }
    }
}

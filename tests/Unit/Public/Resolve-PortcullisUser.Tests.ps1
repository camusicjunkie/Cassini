BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-PortcullisTestEnvironment }

Describe 'Resolve-PortcullisUser' {
    It 'returns DOMAIN\user for a Windows-authenticated user' {
        Resolve-PortcullisUser -AuthUser @{ Username = 'jdoe'; Domain = 'CORP' } | Should -Be 'CORP\jdoe'
    }

    It 'returns the username when there is no domain' {
        Resolve-PortcullisUser -AuthUser @{ Username = 'jdoe' } | Should -Be 'jdoe'
    }

    It 'names the portal account and says there was no sign-in' {
        Resolve-PortcullisUser -AuthUser $null | Should -BeLike "*$([Environment]::UserName) (no authentication)"
    }
}

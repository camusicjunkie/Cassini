BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-CassiniTestEnvironment }

Describe 'Test-CassiniRequestOrigin' {
    It 'allows <Method> whatever the headers' -ForEach @(
        @{ Method = 'GET' }
        @{ Method = 'HEAD' }
        @{ Method = 'OPTIONS' }
    ) {
        (Test-CassiniRequestOrigin -Method $Method -FetchSite 'cross-site' -Origin 'https://evil.blue.local' -HostHeader 'cassini.blue.local').Allowed |
            Should -BeTrue
    }

    It 'decides a POST with Sec-Fetch-Site <FetchSite>: <Allowed>' -ForEach @(
        @{ FetchSite = 'same-origin'; Allowed = $true }
        @{ FetchSite = 'none'; Allowed = $true }
        @{ FetchSite = 'same-site'; Allowed = $false }
        @{ FetchSite = 'cross-site'; Allowed = $false }
    ) {
        # Sec-Fetch-Site decides even when Origin would say otherwise.
        $result = Test-CassiniRequestOrigin -Method POST -FetchSite $FetchSite -Origin 'https://cassini.blue.local' -HostHeader 'cassini.blue.local'

        $result.Allowed | Should -Be $Allowed
        $result.PSObject.TypeNames | Should -Contain 'Cassini.OriginCheck'
    }

    It 'falls back to Origin against Host: <Case>' -ForEach @(
        @{ Case = 'same host, default port'; Origin = 'https://cassini.blue.local'; HostHeader = 'cassini.blue.local'; Allowed = $true }
        @{ Case = 'same host, explicit port'; Origin = 'http://localhost:8080'; HostHeader = 'localhost:8080'; Allowed = $true }
        @{ Case = 'host in another case'; Origin = 'https://Cassini.Blue.Local'; HostHeader = 'cassini.blue.local'; Allowed = $true }
        @{ Case = 'other host in the same domain'; Origin = 'https://evil.blue.local'; HostHeader = 'cassini.blue.local'; Allowed = $false }
        @{ Case = 'same host, other port'; Origin = 'https://cassini.blue.local:8443'; HostHeader = 'cassini.blue.local'; Allowed = $false }
        @{ Case = 'null origin'; Origin = 'null'; HostHeader = 'cassini.blue.local'; Allowed = $false }
        @{ Case = 'not a URL'; Origin = 'cassini'; HostHeader = 'cassini.blue.local'; Allowed = $false }
        @{ Case = 'no Host header'; Origin = 'https://cassini.blue.local'; HostHeader = ''; Allowed = $false }
    ) {
        (Test-CassiniRequestOrigin -Method POST -Origin $Origin -HostHeader $HostHeader).Allowed | Should -Be $Allowed
    }

    It 'allows a POST with no browser headers (a script) and says why' {
        $result = Test-CassiniRequestOrigin -Method POST -HostHeader 'cassini.blue.local'

        $result.Allowed | Should -BeTrue
        $result.Reason | Should -BeLike '*not sent by a browser*'
    }
}

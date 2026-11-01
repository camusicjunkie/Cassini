BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-PortcullisTestEnvironment }

Describe 'Test-PortcullisRequestOrigin' {
    It 'allows <Method> whatever the headers' -ForEach @(
        @{ Method = 'GET' }
        @{ Method = 'HEAD' }
        @{ Method = 'OPTIONS' }
    ) {
        (Test-PortcullisRequestOrigin -Method $Method -FetchSite 'cross-site' -Origin 'https://evil.blue.local' -HostHeader 'portcullis.blue.local').Allowed |
            Should -BeTrue
    }

    It 'decides a POST with Sec-Fetch-Site <FetchSite>: <Allowed>' -ForEach @(
        @{ FetchSite = 'same-origin'; Allowed = $true }
        @{ FetchSite = 'none'; Allowed = $true }
        @{ FetchSite = 'same-site'; Allowed = $false }
        @{ FetchSite = 'cross-site'; Allowed = $false }
    ) {
        # Sec-Fetch-Site decides even when Origin would say otherwise.
        $result = Test-PortcullisRequestOrigin -Method POST -FetchSite $FetchSite -Origin 'https://portcullis.blue.local' -HostHeader 'portcullis.blue.local'

        $result.Allowed | Should -Be $Allowed
        $result.PSObject.TypeNames | Should -Contain 'Portcullis.OriginCheck'
    }

    It 'falls back to Origin against Host: <Case>' -ForEach @(
        @{ Case = 'same host, default port'; Origin = 'https://portcullis.blue.local'; HostHeader = 'portcullis.blue.local'; Allowed = $true }
        @{ Case = 'same host, explicit port'; Origin = 'http://localhost:8080'; HostHeader = 'localhost:8080'; Allowed = $true }
        @{ Case = 'host in another case'; Origin = 'https://Portcullis.Blue.Local'; HostHeader = 'portcullis.blue.local'; Allowed = $true }
        @{ Case = 'other host in the same domain'; Origin = 'https://evil.blue.local'; HostHeader = 'portcullis.blue.local'; Allowed = $false }
        @{ Case = 'same host, other port'; Origin = 'https://portcullis.blue.local:8443'; HostHeader = 'portcullis.blue.local'; Allowed = $false }
        @{ Case = 'null origin'; Origin = 'null'; HostHeader = 'portcullis.blue.local'; Allowed = $false }
        @{ Case = 'not a URL'; Origin = 'portcullis'; HostHeader = 'portcullis.blue.local'; Allowed = $false }
        @{ Case = 'no Host header'; Origin = 'https://portcullis.blue.local'; HostHeader = ''; Allowed = $false }
    ) {
        (Test-PortcullisRequestOrigin -Method POST -Origin $Origin -HostHeader $HostHeader).Allowed | Should -Be $Allowed
    }

    It 'allows a POST with no browser headers (a script) and says why' {
        $result = Test-PortcullisRequestOrigin -Method POST -HostHeader 'portcullis.blue.local'

        $result.Allowed | Should -BeTrue
        $result.Reason | Should -BeLike '*not sent by a browser*'
    }
}

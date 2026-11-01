BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-PortcullisTestEnvironment }

Describe 'Get-PortcullisConfig' {
    BeforeAll {
        function Write-Config ([string] $Body) {
            $path = Join-Path -Path $TestDrive -ChildPath "c-$([guid]::NewGuid()).psd1"
            Set-Content -Path $path -Value $Body -Encoding UTF8
            $path
        }
    }

    It 'fills the defaults when only UpstreamServer is set' {
        $config = Get-PortcullisConfig -Path (Write-Config "@{ UpstreamServer = 'wsus01' }")

        $config.PSObject.TypeNames | Should -Contain 'Portcullis.Config'
        $config.ReplicaServer | Should -Be ''
        $config.Port | Should -Be 8531
        $config.AdminGroup | Should -Be 'res.srv.wsus.admin'
        $config.Authentication | Should -Be 'IIS'
        $config.PreviewMaxAgeMinutes | Should -Be 15
    }

    It 'keeps values from the file' {
        $config = Get-PortcullisConfig -Path (Write-Config "@{ UpstreamServer = 'wsus01'; ReplicaServer = 'wsus02'; Port = '8530'; Authentication = 'None' }")

        $config.ReplicaServer | Should -Be 'wsus02'
        $config.Port | Should -Be 8530
        $config.Port | Should -BeOfType [int]
        $config.Authentication | Should -Be 'None'
    }

    It 'throws for a missing file and names the example' {
        { Get-PortcullisConfig -Path (Join-Path -Path $TestDrive -ChildPath 'nope.psd1') } | Should -Throw '*portcullis.example.psd1*'
    }

    It 'throws for <Case>' -ForEach @(
        @{ Case = 'no UpstreamServer'; Body = "@{ ReplicaServer = 'wsus02' }"; Message = '*UpstreamServer is required*' }
        @{ Case = 'an unknown key'; Body = "@{ UpstreamServer = 'wsus01'; Upstream = 'x' }"; Message = '*Unknown configuration key*Upstream*' }
        @{ Case = 'replica equal to upstream'; Body = "@{ UpstreamServer = 'wsus01'; ReplicaServer = 'wsus01' }"; Message = '*must differ*' }
        @{ Case = 'a bad authentication mode'; Body = "@{ UpstreamServer = 'wsus01'; Authentication = 'Forms' }"; Message = "*'IIS' or 'None'*" }
        @{ Case = 'IIS without an admin group'; Body = "@{ UpstreamServer = 'wsus01'; AdminGroup = '' }"; Message = '*AdminGroup is required*' }
        @{ Case = 'a bad port'; Body = "@{ UpstreamServer = 'wsus01'; Port = 70000 }"; Message = '*Port must be a port number*' }
        @{ Case = 'a bad preview age'; Body = "@{ UpstreamServer = 'wsus01'; PreviewMaxAgeMinutes = 0 }"; Message = '*PreviewMaxAgeMinutes*' }
    ) {
        { Get-PortcullisConfig -Path (Write-Config $Body) } | Should -Throw $Message
    }

    It 'allows no admin group when authentication is None' {
        $config = Get-PortcullisConfig -Path (Write-Config "@{ UpstreamServer = 'wsus01'; AdminGroup = ''; Authentication = 'None' }")
        $config.AdminGroup | Should -Be ''
    }
}

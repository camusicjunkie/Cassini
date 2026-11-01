BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-PortcullisTestEnvironment }

Describe 'Format-PortcullisInstallTime' {
    BeforeAll {
        $script:pilot = [PSCustomObject] @{ Ring = 'Pilot'; Day = 'Thursday'; Hour = 19; Weeks = @(); DetectionHours = 22 }
        $script:workstations = [PSCustomObject] @{ Ring = 'Workstations'; Day = 'Wednesday'; Hour = 19; Weeks = @(); DetectionHours = 22 }
        $script:servers = [PSCustomObject] @{ Ring = 'Servers'; Day = 'Thursday'; Hour = 19; Weeks = @(); DetectionHours = 22 }
    }

    It 'names each promoted ring, in schedule order, leaving Pilot out' {
        Format-PortcullisInstallTime -Schedule $script:pilot, $script:workstations, $script:servers -After ([datetime] '2026-11-17 10:00') |
            Should -Be 'Installs start Wed 18 Nov 19:00 (Workstations) and Thu 19 Nov 19:00 (Servers), client local time.'
    }

    It 'reads naturally with one ring' {
        Format-PortcullisInstallTime -Schedule $script:servers -After ([datetime] '2026-11-17 10:00') |
            Should -Be 'Installs start Thu 19 Nov 19:00 (Servers), client local time.'
    }

    It 'is empty without a promoted ring' {
        Format-PortcullisInstallTime -Schedule $script:pilot | Should -Be ''
    }
}

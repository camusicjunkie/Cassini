BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-PortcullisTestEnvironment }

Describe 'Get-PortcullisInstallSchedule' {
    BeforeAll {
        function Get-ScheduleConfig ([string] $Schedule) {
            $path = Join-Path -Path $TestDrive -ChildPath "c-$([guid]::NewGuid()).psd1"
            Set-Content -Path $path -Value "@{ UpstreamServer = 'wsus01'; Authentication = 'None'; Schedule = $Schedule }" -Encoding UTF8
            Get-PortcullisConfig -Path $path
        }
    }

    It 'uses the configured values for a ring with no GPO' {
        Mock -ModuleName Portcullis Get-PortcullisGpoInstallSetting { throw 'not expected' }
        $config = Get-ScheduleConfig "@{ Pilot = @{ Gpo = '' }; Workstations = @{ Gpo = '' }; Servers = @{ Gpo = ''; Day = 'friday'; Hour = 20 } }"

        $rows = @(Get-PortcullisInstallSchedule -Config $config)

        @($rows.Ring) | Should -Be @('Pilot', 'Workstations', 'Servers')
        $rows[2].Day | Should -Be 'Friday'
        $rows[2].Hour | Should -Be 20
        $rows[2].Source | Should -Be 'Configuration'
        $rows[2].Warning | Should -Be ''
        Should -Invoke -ModuleName Portcullis Get-PortcullisGpoInstallSetting -Times 0
    }

    It 'reads day, hour and detection frequency from the GPO' {
        Mock -ModuleName Portcullis Get-PortcullisGpoInstallSetting { @{ Day = 3; Hour = 18; EveryWeek = $true; Weeks = @(); DetectionHours = 8 } } -ParameterFilter { $Name -eq 'WSUS - Workstations' }
        Mock -ModuleName Portcullis Get-PortcullisGpoInstallSetting { @{ Day = 0; Hour = 2; EveryWeek = $true; Weeks = @(); DetectionHours = $null } }
        $config = Get-ScheduleConfig '@{}'

        $rows = @(Get-PortcullisInstallSchedule -Config $config)
        $workstations = $rows | Where-Object Ring -eq 'Workstations'

        $workstations.Day | Should -Be 'Tuesday'
        $workstations.Hour | Should -Be 18
        $workstations.DetectionHours | Should -Be 8
        $workstations.Source | Should -Be "GPO 'WSUS - Workstations'"
        ($rows | Where-Object Ring -eq 'Servers').Day | Should -Be 'Everyday'
        ($rows | Where-Object Ring -eq 'Servers').DetectionHours | Should -Be 22
    }

    It 'falls back to the configuration, with a warning, when a GPO cannot be read' {
        Mock -ModuleName Portcullis Get-PortcullisGpoInstallSetting { throw 'The GroupPolicy module is not installed.' }
        $config = Get-ScheduleConfig '@{}'

        $pilot = Get-PortcullisInstallSchedule -Config $config | Where-Object Ring -eq 'Pilot'

        $pilot.Day | Should -Be 'Thursday'
        $pilot.Source | Should -Be 'Configuration'
        $pilot.Warning | Should -Be "Could not read GPO 'WSUS - Pilot' (The GroupPolicy module is not installed); using the configured Thursday 19:00."
    }

    It 'warns about a GPO that installs only in some weeks of the month' {
        Mock -ModuleName Portcullis Get-PortcullisGpoInstallSetting { @{ Day = 5; Hour = 19; EveryWeek = $false; Weeks = @(2); DetectionHours = 22 } }
        $config = Get-ScheduleConfig '@{}'

        $pilot = Get-PortcullisInstallSchedule -Config $config | Where-Object Ring -eq 'Pilot'

        $pilot.Weeks | Should -Be @(2)
        $pilot.Warning | Should -BeLike "*week(s) 2 of the month*ScheduledInstallEveryWeek = 1*"
    }
}

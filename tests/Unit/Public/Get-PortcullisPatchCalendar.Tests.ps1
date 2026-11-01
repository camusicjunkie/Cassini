BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-PortcullisTestEnvironment }

Describe 'Get-PortcullisPatchCalendar' {
    BeforeAll {
        $script:schedule = @(
            [PSCustomObject] @{ Ring = 'Pilot'; Day = 'Thursday'; Hour = 19; Weeks = @(); DetectionHours = 22 }
            [PSCustomObject] @{ Ring = 'Workstations'; Day = 'Wednesday'; Hour = 19; Weeks = @(); DetectionHours = 22 }
            [PSCustomObject] @{ Ring = 'Servers'; Day = 'Thursday'; Hour = 19; Weeks = @(); DetectionHours = 22 }
        )
        $script:events = @(Get-PortcullisPatchCalendar -Schedule $script:schedule -Month ([datetime] '2026-11-20'))
        function Find-Event ([string] $Title) { $script:events | Where-Object { $_.Title -eq $Title } }
    }

    It 'follows the WSUS README cycle for November 2026: <Title> on <Date> <Time>' -ForEach @(
        @{ Title = 'Patch Tuesday'; Date = '2026-11-10'; Time = '19:00' }
        @{ Title = 'Sync and Pilot approval'; Date = '2026-11-11'; Time = '' }
        @{ Title = 'Run the Packer build'; Date = '2026-11-11'; Time = '' }
        @{ Title = 'Pilot installs'; Date = '2026-11-12'; Time = '19:00' }
        @{ Title = 'Preview the gate'; Date = '2026-11-16'; Time = '' }
        @{ Title = 'Approve the rings'; Date = '2026-11-17'; Time = '21:00' }
        @{ Title = 'Workstations install'; Date = '2026-11-18'; Time = '19:00' }
        @{ Title = 'Servers install'; Date = '2026-11-19'; Time = '19:00' }
        @{ Title = 'Check for stragglers'; Date = '2026-11-20'; Time = '' }
    ) {
        $found = Find-Event -Title $Title
        $found.Date | Should -Be $Date
        $found.Time | Should -Be $Time
    }

    It 'says what the approval deadline is for' {
        (Find-Event -Title 'Approve the rings').Detail |
            Should -Be 'Approve by Tue 17 Nov 21:00 so clients see it before their window (Workstations Wed 18 Nov 19:00, Servers Thu 19 Nov 19:00).'
    }

    It 'returns the events in time order, typed, with the ring on installs' {
        $sorted = @($script:events | Sort-Object -Property Date, Time)
        @($script:events.Title) | Should -Be @($sorted.Title)
        $script:events[0].PSObject.TypeNames | Should -Contain 'Portcullis.CalendarEvent'
        $script:events[0].PSObject.Properties.Name | Should -Not -Contain 'Sort'
        (Find-Event -Title 'Servers install').Ring | Should -Be 'Servers'
        (Find-Event -Title 'Servers install').Kind | Should -Be 'install'
    }

    It 'finds Patch Tuesday on the <Expected> for <Month>' -ForEach @(
        @{ Month = '2026-10-05'; Expected = '2026-10-13' }
        @{ Month = '2026-09-30'; Expected = '2026-09-08' }
        @{ Month = '2026-12-01'; Expected = '2026-12-08' }
    ) {
        $first = Get-PortcullisPatchCalendar -Schedule $script:schedule -Month ([datetime] $Month) | Select-Object -First 1
        $first.Title | Should -Be 'Patch Tuesday'
        $first.Date | Should -Be $Expected
    }
}

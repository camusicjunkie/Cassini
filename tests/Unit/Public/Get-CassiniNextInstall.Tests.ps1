BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-CassiniTestEnvironment }

Describe 'Get-CassiniNextInstall' {
    BeforeAll {
        function Get-Row ([string] $Ring, [string] $Day, [int] $Hour = 19, [int[]] $Weeks = @(), [int] $Detection = 22) {
            [PSCustomObject] @{ Ring = $Ring; Day = $Day; Hour = $Hour; Weeks = $Weeks; DetectionHours = $Detection }
        }
        $script:schedule = @(
            Get-Row -Ring 'Workstations' -Day 'Wednesday'
            Get-Row -Ring 'Daily' -Day 'Everyday' -Hour 3 -Detection 4
            Get-Row -Ring 'SecondWeek' -Day 'Thursday' -Weeks 2
        )
    }

    It 'takes the first window at least DetectionHours after the approval: <Case>' -ForEach @(
        @{ Case = 'Tuesday morning makes Wednesday'; After = '2026-11-17 08:00'; Start = '2026-11-18 19:00' }
        @{ Case = 'Tuesday 21:00 still makes Wednesday'; After = '2026-11-17 21:00'; Start = '2026-11-18 19:00' }
        @{ Case = 'Tuesday 21:01 misses it'; After = '2026-11-17 21:01'; Start = '2026-11-25 19:00' }
        @{ Case = 'Wednesday afternoon waits a week'; After = '2026-11-18 15:00'; Start = '2026-11-25 19:00' }
    ) {
        $next = Get-CassiniNextInstall -Schedule $script:schedule -Ring 'Workstations' -After ([datetime] $After)

        $next.Start | Should -Be ([datetime] $Start)
        $next.Deadline | Should -Be ([datetime] $Start).AddHours(-22)
        $next.PSObject.TypeNames | Should -Contain 'Cassini.NextInstall'
    }

    It 'handles a daily schedule' {
        (Get-CassiniNextInstall -Schedule $script:schedule -Ring 'Daily' -After ([datetime] '2026-11-17 22:00')).Start |
            Should -Be ([datetime] '2026-11-18 03:00')
        (Get-CassiniNextInstall -Schedule $script:schedule -Ring 'Daily' -After ([datetime] '2026-11-17 23:30')).Start |
            Should -Be ([datetime] '2026-11-19 03:00')
    }

    It 'keeps to the weeks of the month a GPO names' {
        # Patch Tuesday 13 Oct 2026: the Thursday after it (15th) is in week 3, so week 2 means 12 Nov.
        (Get-CassiniNextInstall -Schedule $script:schedule -Ring 'SecondWeek' -After ([datetime] '2026-10-14 06:00')).Start |
            Should -Be ([datetime] '2026-11-12 19:00')
    }

    It 'throws for a ring with no schedule' {
        { Get-CassiniNextInstall -Schedule $script:schedule -Ring 'Pilot' } | Should -Throw "*No schedule for ring 'Pilot'*"
    }
}

function Get-PortcullisPatchCalendar {
    <#
    .SYNOPSIS
        The patch cycle of one month as calendar events: Patch Tuesday, what to do and when each ring installs.
    .DESCRIPTION
        Follows the monthly cycle in the WSUS README (section 5), counted from Patch Tuesday, the second
        Tuesday of the month:

          Patch Tuesday (PT)   Microsoft releases in the evening
          PT + 1               Overnight sync; the rules approve for Packer and Pilot. Run the Packer build.
          Pilot install        First Pilot window after the sync
          PT + 6 (Monday)      Preview the gate (Pilot has soaked five days)
          PT + 7 (Tuesday)     Approve, by the latest time that still makes each ring's next window
          Ring installs        First window of each promoted ring after the approval
          Day after            Check Needed counts for machines that were off

        Install times come from Get-PortcullisInstallSchedule (client local time). Every ring other
        than Pilot is a promoted ring.
    .EXAMPLE
        Get-PortcullisPatchCalendar -Schedule (Get-PortcullisInstallSchedule -Config $config) -Month '2026-11-01'
    .OUTPUTS
        Portcullis.CalendarEvent
    #>
    [CmdletBinding()]
    [OutputType('Portcullis.CalendarEvent')]
    param (
        # Rows from Get-PortcullisInstallSchedule.
        [Parameter(Mandatory)]
        [object[]] $Schedule,

        # Any day in the month to show.
        [Parameter(Mandatory)]
        [datetime] $Month
    )

    $first = [datetime]::new($Month.Year, $Month.Month, 1)
    $patchTuesday = $first.AddDays(((2 - [int] $first.DayOfWeek) + 7) % 7 + 7)

    $newEvent = {
        param ([datetime] $At, [string] $Kind, [string] $Title, [string] $Detail, [string] $Ring = '', [bool] $Timed = $true)
        [PSCustomObject] @{
            PSTypeName = 'Portcullis.CalendarEvent'
            Date       = $At.ToString('yyyy-MM-dd')
            Time       = if ($Timed) { $At.ToString('HH:mm') } else { '' }
            Kind       = $Kind
            Ring       = $Ring
            Title      = $Title
            Detail     = $Detail
            Sort       = $At
        }
    }
    $when = { param ([datetime] $At) $At.ToString('ddd d MMM HH:mm', [Globalization.CultureInfo]::InvariantCulture) }

    $events = [Collections.Generic.List[object]]::new()
    $events.Add((& $newEvent $patchTuesday.AddHours(19) 'release' 'Patch Tuesday' 'Microsoft releases the month''s updates in the evening.'))

    $synced = $patchTuesday.AddDays(1).AddHours(6)
    $events.Add((& $newEvent $synced 'auto' 'Sync and Pilot approval' 'The overnight sync brings the updates in; the rules approve Critical and Security updates for Packer and Pilot.' -Timed $false))
    $events.Add((& $newEvent $synced 'action' 'Run the Packer build' 'A clean build is the first gate.' -Timed $false))

    $pilot = $Schedule | Where-Object { $_.Ring -eq 'Pilot' }
    if ($pilot) {
        $install = Get-PortcullisNextInstall -Schedule $Schedule -Ring 'Pilot' -After $synced
        $events.Add((& $newEvent $install.Start 'install' 'Pilot installs' 'Pilot computers install and restart.' 'Pilot'))
    }

    $previewDay = $patchTuesday.AddDays(6)
    $events.Add((& $newEvent $previewDay 'action' 'Preview the gate' 'Promote rings: run the preview and review the held updates.' -Timed $false))

    $approveDay = $patchTuesday.AddDays(7)
    $promoted = @($Schedule | Where-Object { $_.Ring -ne 'Pilot' })
    $installs = @(foreach ($row in $promoted) {
            Get-PortcullisNextInstall -Schedule $Schedule -Ring $row.Ring -After $approveDay.AddHours(8)
        })
    if ($installs) {
        $deadline = ($installs | Sort-Object -Property Deadline | Select-Object -First 1).Deadline
        $targets = ($installs | ForEach-Object { "$($_.Ring) $(& $when $_.Start)" }) -join ', '
        $events.Add((& $newEvent $deadline 'action' 'Approve the rings' "Approve by $(& $when $deadline) so clients see it before their window ($targets)."))
        foreach ($install in $installs) {
            $events.Add((& $newEvent $install.Start 'install' "$($install.Ring) install" "$($install.Ring) computers install and restart." $install.Ring))
        }
        $last = ($installs | Sort-Object -Property Start | Select-Object -Last 1).Start
        $events.Add((& $newEvent $last.Date.AddDays(1) 'action' 'Check for stragglers' 'Look at the Needed counts for machines that were off during their window.' -Timed $false))
    }

    $events | Sort-Object -Property Sort | Select-Object -Property * -ExcludeProperty Sort | ForEach-Object {
        $_.PSObject.TypeNames.Insert(0, 'Portcullis.CalendarEvent')
        $_
    }
}

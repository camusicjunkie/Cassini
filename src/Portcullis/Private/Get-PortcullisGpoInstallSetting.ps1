function Get-PortcullisGpoInstallSetting {
    <#
    .SYNOPSIS
        Reads a ring GPO's Windows Update install schedule (WSUS README, section 7).
    .DESCRIPTION
        Values under HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU:
          ScheduledInstallDay         0 = every day, 1 = Sunday ... 7 = Saturday
          ScheduledInstallTime        hour, 0 to 23
          ScheduledInstallEveryWeek   1 = every week; otherwise the First..FourthWeek values pick weeks
          DetectionFrequency          hours between scans (with DetectionFrequencyEnabled = 1)

        Throws when the GroupPolicy module is missing, the GPO cannot be read, or it has no install day
        or time. Separate so tests can mock it.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        # GPO display name, e.g. 'WSUS - Workstations'.
        [Parameter(Mandatory)]
        [string] $Name
    )

    if (-not (Get-Module -Name GroupPolicy -ListAvailable)) {
        throw 'The GroupPolicy module is not installed (Install-WindowsFeature GPMC).'
    }
    Import-Module -Name GroupPolicy -ErrorAction Stop

    $key = 'HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU'
    $read = {
        param ([string] $ValueName)
        $value = GroupPolicy\Get-GPRegistryValue -Name $Name -Key $key -ValueName $ValueName -ErrorAction SilentlyContinue
        if ($value) { $value.Value -as [int] }
    }

    $day = & $read 'ScheduledInstallDay'
    $hour = & $read 'ScheduledInstallTime'
    if ($null -eq $day -or $null -eq $hour) {
        throw "GPO '$Name' has no ScheduledInstallDay or ScheduledInstallTime."
    }

    $weeks = @(
        $number = 0
        foreach ($ordinal in 'First', 'Second', 'Third', 'Fourth') {
            $number++
            if ((& $read "ScheduledInstall${ordinal}Week") -eq 1) { $number }
        }
    )
    $detection = if ((& $read 'DetectionFrequencyEnabled') -eq 1) { & $read 'DetectionFrequency' }

    @{
        Day            = $day
        Hour           = $hour
        EveryWeek      = (& $read 'ScheduledInstallEveryWeek') -eq 1 -or $weeks.Count -eq 0
        Weeks          = $weeks
        DetectionHours = $detection
    }
}

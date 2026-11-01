# Portcullis configuration. Copy to config/portcullis.psd1 (gitignored) and edit.
# Only UpstreamServer is required; the values below are the defaults.
@{
    # The WSUS upstream (WSUS01). Approvals, declines and lookups run here.
    UpstreamServer       = 'wsus01.corp.local'

    # The replica (WSUS02). Leave empty to show the upstream only.
    ReplicaServer        = 'wsus02.corp.local'

    # WSUS SSL port on both nodes.
    Port                 = 8531

    # AD group allowed to use the portal (nested membership counts).
    AdminGroup           = 'res.srv.wsus.admin'

    # IIS: Windows Authentication in IIS (production).
    # None: no sign-in, localhost only, refused under IIS (local development only).
    Authentication       = 'IIS'

    # Port for a local run. Under IIS, IIS assigns the port and this is ignored.
    ListenPort           = 8080

    # One JSON line per change made through the portal.
    AuditLogPath         = 'C:\ProgramData\Portcullis\audit.log'

    # How long a preview can still be confirmed.
    PreviewMaxAgeMinutes = 15

    # Sign-in session idle time-out (5 to 480).
    SessionMinutes       = 15

    # Required: refuse to start unless the 'Portcullis' Application event source exists, so every
    # change also reaches the Event Log (and Splunk), where the portal's account cannot rewrite it.
    # Default Required under IIS, Optional with Authentication = None.
    AuditEventLog        = 'Required'

    # Shown in the browser tab and the top bar.
    Title                = 'Portcullis'

    # When each ring installs, for the calendar and the install times on Promote rings. The portal
    # reads day, hour and DetectionFrequency from each Gpo (needs the GroupPolicy module: GPMC);
    # the values here are used when Gpo is '' or cannot be read. Hours are client local time.
    # DetectionHours: an approval reaches a client within this many hours, so it installs at the
    # first window at least that long after it.
    Schedule             = @{
        Pilot        = @{ Gpo = 'WSUS - Pilot'; Day = 'Thursday'; Hour = 19; DetectionHours = 22 }
        Workstations = @{ Gpo = 'WSUS - Workstations'; Day = 'Wednesday'; Hour = 19; DetectionHours = 22 }
        Servers      = @{ Gpo = 'WSUS - Servers'; Day = 'Thursday'; Hour = 19; DetectionHours = 22 }
    }
}

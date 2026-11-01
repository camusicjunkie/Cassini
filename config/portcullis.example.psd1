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

    # Shown in the browser tab and the top bar.
    Title                = 'Portcullis'
}

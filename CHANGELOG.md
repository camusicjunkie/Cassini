# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- Pode 2.14.2 (from 2.14.1): the session cookie's `Max-Age` is a whole number again (it was sent as
  e.g. `899.9954201`), in-memory session clean-up no longer fails with "collection was modified", and
  failed sockets are cleaned up. Nothing in the portal's code needed to change.
- Renamed from Portcullis to Cassini: the module, every function (`*-Cassini*`), the `Cassini.*` type
  names, the `Cassini` event source, `C:\ProgramData\Cassini`, `config/cassini.psd1`, `public/cassini.css`
  and `cassini.js` (class prefix `cs-`), and the repository.

### Added

- Patch calendar page: the month's cycle from Patch Tuesday (sync and Pilot approval, Packer build,
  Pilot install, preview, the approval deadline, Workstations and Servers installs, straggler check),
  with month navigation, keyboard arrows, a day panel, and dots on phones. Served from
  `GET /api/v1/calendar` (`Get-CassiniPatchCalendar`).
- Install schedule from the ring GPOs (`Get-CassiniInstallSchedule`, read hourly), with `Schedule` in
  the configuration as the fallback and a warning for a GPO that installs only in some weeks of the month.
  An approval reaches the first window at least `DetectionHours` (22) after it
  (`Get-CassiniNextInstall`).
- Promote rings says when the rings will install: with the preview ("if approved now") and with the last
  approval (`Format-CassiniInstallTime`).
- Security ([docs/security.md](docs/security.md)): POSTs sent from another site are refused with 403
  and logged (`Test-CassiniRequestOrigin`); the session cookie is `Secure` and `HttpOnly` with an
  idle time-out of `SessionMinutes` (default 15); every response has a Content-Security-Policy
  (scripts from the portal only), frame, content-type, referrer, cross-origin, permissions and HSTS
  headers, and no CORS headers (Pode.Web's preset allowed any origin); `web.config` drops the
  `Server` and `X-Powered-By` headers and allows only GET, HEAD and POST up to 1 MB.
- `AuditEventLog` (default `Required` under IIS): the server refuses to start without the
  `Cassini` event source (`Assert-CassiniAuditSource`), so every change also reaches the Event
  Log.
- Status page: both WSUS nodes from `Get-WsusNodeStatus`, refreshed every minute, with notes for an
  unreachable node, a role that differs from the configuration, and a replica behind the upstream.
  Start a sync on either node. A refresh swaps the rows in place: the table keeps its rows and
  height, with no spinner, until the new data arrives (`public/cassini.js`).
- Promote rings page: preview the `Approve-WsusRing` gate with soak, installed percent and Force, then
  confirm to approve what passed.
- Decline page: look up a KB on the upstream with the same exact match as `Deny-WsusUpdate`, then confirm
  to decline it.
- Audit page and audit log: every change, with the user who confirmed it, as a JSON line and optionally
  an Application event.
- Previews are kept server-side in the session, expire after `PreviewMaxAgeMinutes`, and are confirmed
  by id only.
- Own theme over Pode.Web (`public/cassini.css`), light and dark: system font, flat cards with
  chevron collapse buttons, lighter tables, near-white disabled buttons, spaced buttons, a hamburger
  toggle and an icon rail when the sidebar is collapsed. Empty result tables stay hidden.
- Sidebar: hover only changes the colour; icons keep the same place and row height whether the
  sidebar is open or collapsed, and a collapsed sidebar stays collapsed across pages.
- `cassini.css` and `cassini.js` are requested with a hash of the file in the URL, so a new
  version shows at once instead of after the browser's cached copy expires.
- Light/dark toggle in the top bar (kept in Pode.Web's theme cookie).
- After an approval, the Preview on Promote rings keeps only the updates still pending
  (`Select-CassiniPendingRow`); Last approval lists only the updates actually approved, and a run
  that approves nothing leaves the previous Last approval in place.
- Table control rows (refresh, page size, page links) sit below the table, all 2rem tall, with refresh
  flush with the table's left edge and the page controls flush with its right edge; the
  open sidebar has a fixed width so page names fit on narrow windows.
- Promote rings keeps the last approval (who, when, what) in the session and shows it again when
  the page is reopened.
- Space between a table and the button under it.
- Gate reasons and messages start with a capital letter.
- Readable table headers, blank cells instead of "undefined", and words kept whole in table cells
  (`public/cassini.css`); wide tables scroll sideways.
- Pode 2.14.2 and Pode.Web 1.0.0 pinned as `RequiredModules` in the Cassini manifest.
- Windows Authentication through IIS, limited to an AD group; a localhost-only mode without sign-in for
  development, with fake WSUS data (`dev/Start-DevServer.ps1`). The fake WSUS remembers ring
  approvals until the dev server stops, so an approved update is gone from the next preview, as on a
  real upstream.

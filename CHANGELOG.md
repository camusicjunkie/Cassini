# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Status page: both WSUS nodes from `Get-WsusNodeStatus`, refreshed every minute, with notes for an
  unreachable node, a role that differs from the configuration, and a replica behind the upstream.
  Start a sync on either node. A refresh swaps the rows in place: the table keeps its rows and
  height, with no spinner, until the new data arrives (`public/portcullis.js`).
- Promote rings page: preview the `Approve-WsusRing` gate with soak, installed percent and Force, then
  confirm to approve what passed.
- Decline page: look up a KB on the upstream with the same exact match as `Deny-WsusUpdate`, then confirm
  to decline it.
- Audit page and audit log: every change, with the user who confirmed it, as a JSON line and optionally
  an Application event.
- Previews are kept server-side in the session, expire after `PreviewMaxAgeMinutes`, and are confirmed
  by id only.
- Own theme over Pode.Web (`public/portcullis.css`), light and dark: system font, flat cards with
  chevron collapse buttons, lighter tables, near-white disabled buttons, spaced buttons, a hamburger
  toggle and an icon rail when the sidebar is collapsed. Empty result tables stay hidden.
- Sidebar: hover only changes the colour; icons keep the same place and row height whether the
  sidebar is open or collapsed, and a collapsed sidebar stays collapsed across pages.
- `portcullis.css` and `portcullis.js` are requested with a hash of the file in the URL, so a new
  version shows at once instead of after the browser's cached copy expires.
- Light/dark toggle in the top bar (kept in Pode.Web's theme cookie).
- After an approval, the Preview on Promote rings keeps only the updates still pending
  (`Select-PortcullisPendingRow`); Last approval lists only the updates actually approved, and a run
  that approves nothing leaves the previous Last approval in place.
- Table control rows (refresh, page size, page links) sit below the table, all 2rem tall, with refresh
  flush with the table's left edge and the page controls flush with its right edge; the
  open sidebar has a fixed width so page names fit on narrow windows.
- Promote rings keeps the last approval (who, when, what) in the session and shows it again when
  the page is reopened.
- Space between a table and the button under it.
- Gate reasons and messages start with a capital letter.
- Readable table headers, blank cells instead of "undefined", and words kept whole in table cells
  (`public/portcullis.css`); wide tables scroll sideways.
- Pode 2.14.1 and Pode.Web 1.0.0 pinned as `RequiredModules` in the Portcullis manifest.
- Windows Authentication through IIS, limited to an AD group; a localhost-only mode without sign-in for
  development, with fake WSUS data (`dev/Start-DevServer.ps1`). The fake WSUS remembers ring
  approvals until the dev server stops, so an approved update is gone from the next preview, as on a
  real upstream.

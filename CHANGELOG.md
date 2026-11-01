# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Status page: both WSUS nodes from `Get-WsusNodeStatus`, refreshed every minute, with notes for an
  unreachable node, a role that differs from the configuration, and a replica behind the upstream.
  Start a sync on either node.
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
- Light/dark toggle in the top bar (kept in Pode.Web's theme cookie).
- Promote rings keeps the last approval (who, when, what) in the session and shows it again when
  the page is reopened.
- Space between a table and the button under it.
- Gate reasons and messages start with a capital letter.
- Readable table headers, blank cells instead of "undefined", and words kept whole in table cells
  (`public/portcullis.css`); wide tables scroll sideways.
- Pode 2.14.1 and Pode.Web 1.0.0 pinned as `RequiredModules` in the Portcullis manifest.
- Windows Authentication through IIS, limited to an AD group; a localhost-only mode without sign-in for
  development, with fake WSUS data (`dev/Start-DevServer.ps1`).

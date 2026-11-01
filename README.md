# Portcullis

A web portal for the two-node WSUS setup (the [WSUS module](https://github.com/camusicjunkie/WSUS)), built
with [Pode](https://github.com/Badgerati/Pode) and [Pode.Web](https://github.com/Badgerati/Pode.Web). It
puts the monthly and day-to-day WSUS jobs behind a browser, so they no longer need a PowerShell session on
an admin workstation. Every change is a preview first, then a confirm, and is recorded in an audit log.

| Page | What it does | WSUS module call |
|------|--------------|------------------|
| Status | Both nodes: role, sync state and progress, last sync, update/approved/declined counts, content left to download. Refreshes every minute. Start a sync on either node. | `Get-WsusNodeStatus`, `Start-WsusSync` |
| Promote rings | Preview the gate (soak, installed percent, optional Force), then approve what passed. | `Approve-WsusRing -WhatIf`, then `Approve-WsusRing` |
| Decline an update | Look up a KB on the upstream (exact match, every variant), then decline it. | read-only lookup, then `Deny-WsusUpdate` |
| Audit | The newest changes made through the portal, with who confirmed each one. | – |

It covers what the WSUS README's monthly cycle (section 5) and bad-update steps (section 8) ask an admin to
run. Building, configuring, promoting a replica and maintenance stay in PowerShell: they are rare, run
locally on a node, and need a person watching.

## How a change is made safely

1. **Preview.** The page runs the read-only version (`Approve-WsusRing -WhatIf`, or the KB lookup) and
   shows exactly what would change. The server keeps a record of the preview in your session: its
   settings, an id and the time.
2. **Confirm.** The confirm dialog carries only the preview id. The server runs with the settings stored
   in the preview, never with values from the browser, and refuses if the id doesn't match, the preview is
   of the other kind, or it's older than `PreviewMaxAgeMinutes` (15). Each preview can be confirmed once.
3. **Audit.** The user, action, node, settings and outcome go to the audit log (a JSON line per change)
   and, if the event source is registered, to the Application event log (ID 1000 success, 1001 failure)
   for Cribl and Splunk. Failures are recorded too.

`Approve-WsusRing` checks the gate again on confirm, so the result can differ slightly from the preview if
Pilot installs changed in between. The result table shows what was actually approved.

## Who can use it, and as whom it runs

- Under IIS with Windows Authentication, only members of `AdminGroup` (default `res.srv.wsus.admin`,
  nested membership counts) get in. Everyone else is refused.
- Changes run as the **portal's service account** (the IIS app pool identity), not as the signed-in
  user: passing a user's Kerberos ticket on to the WSUS nodes would need constrained delegation. WSUS
  therefore sees only that account, and the audit log is what ties each change to a person. Use a gMSA and
  give it WSUS administrator rights on both nodes (add it to `res.srv.wsus.admin`).

## Requirements

- Windows Server with IIS, the ASP.NET Core Module V2 (in the .NET Hosting Bundle) and Windows
  Authentication. See [docs/hosting-iis.md](docs/hosting-iis.md).
- Windows PowerShell 5.1 with these modules installed for all users:
  - `WSUS` from the internal gallery (as in the WSUS README, section 1),
  - `UpdateServices` (the RSAT WSUS API: `Install-WindowsFeature UpdateServices-API`),
  - `Pode` 2.14.1 and `Pode.Web` 1.0.0 (see the note below).
- Network: the portal host to both nodes on 8531.

**Pode.Web version.** The only stable Pode.Web release is 0.8.3, from February 2023. Portcullis targets
1.0.0 (preview3, May 2026), which is what the project is maintained on and which works with current Pode.
`Portcullis.psd1` pins both as `RequiredModules` (Pode 2.14.1, Pode.Web 1.0.0), so the server stops at
start-up with a clear error if either is missing or a different version. A manifest can't name a
prerelease label, so the Pode.Web entry matches any 1.0.0 build; install it with `-AllowPrerelease`. To
move to a newer version, change the manifest and test first: preview APIs can change.

## Configuration

Copy `config/portcullis.example.psd1` to `config/portcullis.psd1` (gitignored) and set at least
`UpstreamServer`. Every key is documented in the example. An unknown key or a bad value stops the server
at start-up rather than running half-configured.

After a promotion (WSUS README, section 11), swap `UpstreamServer` and `ReplicaServer`. Until then the
status page flags the mismatch.

## Run it locally

No WSUS server needed: `dev/Start-DevServer.ps1` runs the real server against fake WSUS and
UpdateServices modules with canned data, with no sign-in, on `http://localhost:8080`.

```powershell
Install-Module Pode -RequiredVersion 2.14.1 -Scope CurrentUser
Install-Module Pode.Web -RequiredVersion 1.0.0-preview3 -AllowPrerelease -Scope CurrentUser
./dev/Start-DevServer.ps1
./dev/Start-DevServer.ps1 -ReplicaServer wsus02-offline.corp.local   # see an unreachable node
```

`Authentication = 'None'` only listens on localhost and refuses to start under IIS.

## Layout

```
server.ps1                  the Pode.Web pages: layout and wiring only
server.psd1                 Pode settings (request timeout)
web.config                  IIS hosting
config/                     portcullis.example.psd1 (copy to portcullis.psd1)
public/                     static files Pode serves (portcullis.css)
src/Portcullis/             the logic as a module (requires Pode and Pode.Web; it never calls them), unit-tested
  Public/                   one exported function per file
  Private/                  shared helpers (preview checks, audit writer, formatting)
dev/                        local run with fake WSUS data
tests/                      Pester tests; stubs of WSUS and UpdateServices, and stand-ins for Pode and
                            Pode.Web so the tests need neither installed
```

## Develop

`./build.ps1 -Task All` is the one check, same as CI: PSScriptAnalyzer (5.1 syntax and cmdlet
compatibility), then Pester. Enable the pre-push hook once per clone: `git config core.hooksPath .githooks`.

## Possible next steps

- Ask the WSUS module for a read-only `Get-WsusUpdate -Kb`, so `Find-PortcullisUpdate` stops duplicating
  `Deny-WsusUpdate`'s exact-match rule.
- Keycloak (OIDC) sign-in instead of Windows Authentication, if the portal moves to the cluster.

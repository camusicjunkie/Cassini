# Security

Cassini can approve updates for every Windows machine that WSUS serves. Whoever controls the portal,
or the account it runs as, controls what those machines install. This page lists what the portal does
about that, what the server around it has to do, and the plan for the parts outside this repository.

## What is being protected

| Asset | Why it matters |
|-------|----------------|
| Approvals and declines on the upstream | Decide what a few thousand machines install |
| The portal's service account (gMSA) | WSUS administrator on both nodes; can do anything the WSUS API allows, without the portal |
| The audit trail | The only record of which person made a change (WSUS only sees the gMSA) |
| The portal server | Holds the gMSA's session and the audit file |

## Threats and the controls against them

| Threat | Control | Where |
|--------|---------|-------|
| Someone outside the admin group uses the portal | Windows Authentication in IIS; only `AdminGroup` members (nested counts) get in | IIS, `server.ps1` |
| Sign-in turned off by mistake in production | `Authentication = None` refuses to start under IIS and only listens on localhost | `server.ps1` |
| Another page makes an admin's browser send a change (CSRF) | POSTs that the browser marks as cross-site or same-site, or whose `Origin` is another host, get 403 and are logged | `Test-CassiniRequestOrigin`, middleware in `server.ps1` |
| A change made with values tampered with in the browser | Confirm runs the parameters stored in the server-side session; the browser only sends the preview id | `Assert-CassiniPreview` |
| An old or replayed confirm | Previews expire after `PreviewMaxAgeMinutes`, can be confirmed once, and must be of the right kind | `Assert-CassiniPreview` |
| An arbitrary approval | The portal can only promote rings through the `Approve-WsusRing` gate, decline a KB and start a sync | Cassini module |
| Bad input (KB text, numbers) | KB format checked; soak and percent ranges checked before WSUS is called | `Find-CassiniUpdate`, `server.ps1` |
| Script injection (XSS) | Pode.Web escapes table cells; Content-Security-Policy allows scripts from the portal only (`script-src 'self'`) | Pode.Web, `server.ps1` |
| Clickjacking (the portal in a hidden frame) | `frame-ancestors 'none'` and `X-Frame-Options: DENY` | `server.ps1` |
| Other sites reading portal responses | No CORS headers (Pode.Web's preset, which allowed any origin, is off); `Cross-Origin-Resource-Policy` and `-Opener-Policy` `same-origin` | `server.ps1` |
| Session cookie stolen or reused | `Secure`, `HttpOnly`, bound to the browser's user agent; 15-minute idle time-out (`SessionMinutes`) | `server.ps1` |
| Downgrade to HTTP | HTTPS-only site; `Strict-Transport-Security` for a year | IIS, `server.ps1` |
| Leaking versions and paths | No `Server` or `X-Powered-By` headers; `Referrer-Policy: no-referrer` | `web.config`, `server.ps1` |
| Unexpected methods or large bodies | Only GET, HEAD and POST; bodies over 1 MB refused | `web.config` |
| A change with no record, or a record that is quietly edited | The audit file is written before the change returns, or the change reports a failure; with `AuditEventLog = 'Required'` (the default under IIS) the server will not start without the event source, so every change also reaches the Event Log and Splunk | `Write-CassiniAudit`, `Assert-CassiniAuditSource` |
| Reading data through the API | `GET /api/v1/calendar` is read-only, behind the same Windows sign-in, with the same headers; its one parameter must match `yyyy-MM` | `server.ps1` |
| Dependencies loaded from the internet | Pode.Web serves its own copies of jQuery, Bootstrap and the rest; nothing comes from a CDN | Pode.Web |

How these were checked: unit tests for every decision function (`./build.ps1 -Task All`), and a
browser run against the dev server that walks every page and flow with no CSP violations, then submits
a form to the sync endpoint from another origin (403, logged, nothing audited) and posts with a forged
`Origin` (403).

## Known limits

- **The gMSA is the real key.** Anyone who runs code as it, on the portal server or anywhere it can log
  on, can use the WSUS API directly. The server hardening below is what protects it.
- **The audit file can be rewritten by the gMSA.** The Event Log copy, forwarded to Splunk, is the one
  to trust; the file feeds the Audit page.
- **No `SameSite` on the session cookie.** Pode cannot set it. The origin check already stops cross-site
  POSTs; the IIS rule in step 6 below adds `SameSite=Strict` as a second layer.
- **`style-src 'unsafe-inline'`.** Pode.Web sets inline style attributes. Scripts stay `'self'` only,
  so this allows styling, not code.
- **Pode.Web is a prerelease** (1.0.0-preview3). Treat each upgrade as a change to review (step 10).
- **No absolute session lifetime.** A session ends after `SessionMinutes` of inactivity, not after a
  fixed time. Windows Authentication signs the user in again either way.

## Implementation plan for everything outside the repository

Do steps 1 to 8 before the portal goes live; 9 to 12 within the first month and then as listed.

| # | Step | Who |
|---|------|-----|
| 1 | Harden the server | You |
| 2 | Service account and groups | You, AD |
| 3 | Certificate and HTTPS binding | You, PKI |
| 4 | Kerberos only, with Extended Protection | You |
| 5 | Browser zone policy | GPO owner |
| 6 | `SameSite=Strict` through URL Rewrite | You |
| 7 | Folder permissions | You |
| 8 | Event source, log forwarding and alerts | You, Splunk/Cribl |
| 9 | Sign the release, enforce `AllSigned` | You (GitLab, HSM) |
| 10 | Upgrade review for Pode and Pode.Web | You |
| 11 | Scan and STIG review | You, ISSO |
| 12 | Back up config and audit trail | You |

### 1. Harden the server

- Windows Server 2025 Core, joined to the domain, used for nothing else.
- Apply the Windows Server 2025 STIG and the IIS 10.0 Server and Site STIGs. TLS 1.2 and later only, as
  the STIG sets through Schannel.
- Treat it as a management (Tier 1) server: only the WSUS admins and server admins may log on, through
  the usual admin workstations.
- Firewall: allow 443 inbound only from the admin subnets or admin workstations; nothing else inbound
  except the management ports you already allow.

  ```powershell
  New-NetFirewallRule -DisplayName 'Cassini HTTPS' -Direction Inbound -Protocol TCP -LocalPort 443 `
      -RemoteAddress '10.0.10.0/24' -Action Allow -Profile Domain
  ```

- Outbound it needs both WSUS nodes on 8531, the domain controllers, and your log forwarding.
- Defender (or your EDR) on, as on every server.

**Check:** a STIG scan with no open findings that you have not accepted; 443 refused from a
non-admin subnet.

### 2. Service account and groups

Keep "who may use the portal" and "what the portal may do to WSUS" in separate groups:

- `res.srv.wsus.admin`: the people. `AdminGroup` points here.
- A resource group for the service account only (for example `res.srv.wsus.portal`), holding
  `gmsa-cassini$`. Nest this group into WSUS Administrators on both nodes.

The gMSA needs no other rights: not local admin on the nodes or the portal server, no interactive
logon. Allow only the portal server to retrieve its password (`PrincipalsAllowedToRetrieveManagedPassword`).

Alert on membership changes to both groups (step 8).

**Check:** the gMSA can run `Get-WsusNodeStatus` against both nodes, and cannot log on interactively
anywhere.

### 3. Certificate and HTTPS binding

- Choose the name: the server's own FQDN, or an alias such as `cassini.corp.local` (an A record to
  the server). An alias needs an SPN: `setspn -S HTTP/cassini.corp.local <SERVER>`.
- Request a certificate with that name in the SAN and the Server Authentication EKU, from the CA that
  issued the WSUS certificates.
- Bind it on 443 and remove any HTTP binding:

  ```powershell
  Import-Module WebAdministration

  $thumbprint = (Get-ChildItem -Path 'Cert:\LocalMachine\My' |
      Where-Object { $_.DnsNameList.Unicode -contains 'cassini.corp.local' } |
      Sort-Object -Property NotAfter | Select-Object -Last 1).Thumbprint

  New-WebBinding -Name 'Cassini' -Protocol https -Port 443
  (Get-WebBinding -Name 'Cassini' -Protocol https -Port 443).AddSslCertificate($thumbprint, 'My')
  Get-WebBinding -Name 'Cassini' -Protocol http | Remove-WebBinding
  ```

- Put the renewal date in the same calendar as the WSUS certificates.

**Check:** `https://cassini.corp.local/` loads with no certificate warning; `http://` does not answer.

### 4. Kerberos only, with Extended Protection

With the SPN in place, take NTLM out of the site and require channel binding, which stops a captured
sign-in from being relayed to the portal:

```powershell
$appcmd = "$env:windir\System32\inetsrv\appcmd.exe"
& $appcmd set config 'Cassini' -section:system.webServer/security/authentication/windowsAuthentication `
    /~"providers" /+"providers.[value='Negotiate:Kerberos']" /commit:apphost
& $appcmd set config 'Cassini' -section:system.webServer/security/authentication/windowsAuthentication `
    /extendedProtection.tokenChecking:"Require" /commit:apphost
```

**Check:** `klist` on an admin workstation shows an `HTTP/cassini.corp.local` ticket after browsing to
the portal; sign-in still works with no prompt. If it prompts, the SPN or the zone policy (step 5) is
missing. Don't fall back to NTLM.

### 5. Browser zone policy

Edge and Chrome only sign in silently with Kerberos to sites in the Local Intranet zone, and a dotted
name is Internet zone by default. By GPO, add `https://cassini.corp.local` to the Site to Zone
Assignment List as zone 1, or allow it in the Edge and Chrome `AuthServerAllowlist` policies.

**Check:** no sign-in prompt from a standard admin workstation.

### 6. `SameSite=Strict` through URL Rewrite

Install the IIS URL Rewrite module, then add this inside `<system.webServer>` in the deployed
`web.config` (not in the repository's copy: without the module, the section stops the site starting):

```xml
<rewrite>
  <outboundRules>
    <rule name="Session cookie SameSite=Strict">
      <match serverVariable="RESPONSE_Set_Cookie" pattern="^(pode\.sid=.*)$" />
      <conditions>
        <add input="{R:1}" pattern="SameSite=" negate="true" />
      </conditions>
      <action type="Rewrite" value="{R:1}; SameSite=Strict" />
    </rule>
  </outboundRules>
</rewrite>
```

**Check:** in the browser's developer tools, the `pode.sid` cookie shows `SameSite=Strict`, and the
pages still work after following a link to the portal from another site.

### 7. Folder permissions

```powershell
$account = 'CORP\gmsa-cassini$'
$site = 'D:\Sites\Cassini'

# Site and config: read only. Logs: written by IIS (stdout) and Pode.
icacls $site /inheritance:r /grant:r 'BUILTIN\Administrators:(OI)(CI)F' 'NT AUTHORITY\SYSTEM:(OI)(CI)F' "${account}:(OI)(CI)RX"
icacls "$site\logs" /grant "${account}:(OI)(CI)M"

# Audit folder: the gMSA writes but cannot delete.
icacls 'C:\ProgramData\Cassini' /inheritance:r /grant:r 'BUILTIN\Administrators:(OI)(CI)F' 'NT AUTHORITY\SYSTEM:(OI)(CI)F' "${account}:(OI)(CI)(RX,W)"
```

**Check:** the portal starts and records a sync; the gMSA cannot change files in `config\` or delete
`audit.log`.

### 8. Event source, log forwarding and alerts

1. Register the event source once, elevated: `New-EventLog -LogName Application -Source Cassini`.
   The portal will not start without it.
2. Forward with Cribl Edge on the portal server: Application events from source `Cassini` (1000
   succeeded, 1001 failed), Pode's error log (`logs\cassini_errors_*.log`, which includes every
   refused cross-site request), and the IIS W3C logs (who requested what, with the signed-in user).
3. Splunk alerts:

   | Alert | From |
   |-------|------|
   | A change failed | Event 1001 |
   | A change outside the patch cycle (approvals not on Tuesday of week 2, out-of-band excepted) | Event 1000 with `ApproveRing` |
   | A request refused as cross-site | Pode error log, `Refused` |
   | Repeated 401 or 403 for one user | IIS logs |
   | Membership change to `res.srv.wsus.admin` or the service-account group | DC events 4728, 4732, 4756 |
   | No audit events or IIS hits for a long time while syncs ran | Heartbeat search |

**Check:** each alert fires once on a test event.

### 9. Sign the release, enforce `AllSigned`

- In the internal GitLab pipeline: `./build.ps1 -Task Release`, then sign every `.ps1`, `.psm1` and
  `.psd1` in `artifacts/stage/Cassini` with the HSM-backed code-signing certificate, with a timestamp,
  then publish the signed folder as the deployable artifact.
- Pode and Pode.Web from the gallery are not signed with your certificate. Sign them the same way when
  you publish them to the internal gallery, or `AllSigned` will stop the portal starting.
- On the portal server, by GPO: execution policy `AllSigned` (Machine policy), and the signing
  certificate in Trusted Publishers. If you use WDAC or AppLocker script rules, allow that publisher.

**Check:** the portal starts; changing one byte in `server.ps1` stops it with a signature error in
`logs\stdout_*.log`.

### 10. Upgrade review for Pode and Pode.Web

Before moving either pinned version:

- Read the release notes for security fixes and changed defaults (Pode.Web's security preset is how
  wildcard CORS got in; the portal now turns it off).
- Run `./build.ps1 -Task All`, then the browser run on the dev server: every page and flow, with the
  console open for CSP violations, and a cross-site POST that must get 403.
- Check the bundled JavaScript libraries' versions against your vulnerability scanner.

### 11. Scan and STIG review

- Scan the portal server with ACAS once it is built, and monthly with everything else.
- Review the portal against the Application Security and Development STIG with your ISSO. This page,
  the audit trail and the Splunk alerts are the evidence for most of the session, audit and access
  checks.

### 12. Back up config and audit trail

Back up `config\cassini.psd1` and `C:\ProgramData\Cassini\audit.log` with the server. Splunk's
retention for the forwarded events is the long-term record; set it to your audit retention requirement.

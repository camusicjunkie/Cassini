# Hosting Portcullis in IIS

Pode runs as a separate `powershell.exe` process behind IIS. IIS handles Windows Authentication and
forwards the signed-in user's token to Pode, which checks the AD group.

The host isn't decided yet. Either works:

- **An admin or utility server.** Keeps a web server off the WSUS nodes. Disk and log facts don't
  show (they are local-only in `Get-WsusNodeStatus`).
- **WSUS01.** IIS is already there, but the WSUS site and this site then share a box that patches
  thousands of clients. If WSUS01 is down, so is the portal.

## 1. Prerequisites on the host

```powershell
Install-WindowsFeature Web-Server, Web-Windows-Auth, UpdateServices-API
```

- Install the **.NET Hosting Bundle** (it provides the ASP.NET Core Module V2). Pode itself doesn't need
  .NET Core; IIS needs the module to start and proxy the process.
- Install the modules for all users from the internal gallery (Windows PowerShell 5.1):

```powershell
Install-Module WSUS -Repository LocalGallery -Scope AllUsers -Force -Credential (Get-Credential)
Install-Module Pode -RequiredVersion 2.14.1 -Repository LocalGallery -Scope AllUsers
Install-Module Pode.Web -RequiredVersion 1.0.0-preview3 -AllowPrerelease -Repository LocalGallery -Scope AllUsers
```

## 2. Service account

Create a gMSA (for example `gmsa-portcullis$`), allow the host to retrieve its password, and add it to
`res.srv.wsus.admin`. That gives it WSUS administrator rights on both nodes. It also needs:

- Read and execute on the site folder (including `config\`; it never writes there).
- Modify on the audit log folder (`C:\ProgramData\Portcullis` by default) and on `logs\` in the site folder.

## 3. Site

1. Copy the staged release (`./build.ps1 -Task Release` puts it in `artifacts/stage/Portcullis`) to,
   for example, `D:\Sites\Portcullis`.
2. Copy `config\portcullis.example.psd1` to `config\portcullis.psd1` and edit it.
3. Create an app pool: **No Managed Code**, identity `CORP\gmsa-portcullis$`, Start Mode AlwaysRunning,
   Idle Time-out 0 (so the first request after a quiet night doesn't wait for PowerShell to start).
4. Create the site on that pool, HTTPS only, with a certificate trusted by the admins' browsers.
5. In Authentication: **Windows Authentication** on, **Anonymous** off (web.config sets both; IIS
   must allow the override, or set it in the IIS manager).

## 4. Event log source (optional, for Splunk)

Once, elevated:

```powershell
New-EventLog -LogName Application -Source Portcullis
```

Without it the audit file is still written. With it, each change is also an Application event (1000
succeeded, 1001 failed) for the existing Cribl Edge/Splunk forwarding.

## 5. Check it

- Browse to the site as a member of the admin group: the Status page shows both nodes.
- Browse as a non-member: refused, with the message naming the admin group.
- Start a sync on the replica, then open the Audit page: the entry shows your name, not the gMSA.
- If the site doesn't start, read `logs\stdout_*.log` in the site folder and Pode's error log in `logs\`.

## Request time-outs

A ring preview walks every Pilot approval; on a large catalog it can take a few minutes. `server.psd1`
(Pode, 300 s) and `requestTimeout` in `web.config` (5 minutes) are set to match. Raise both together.

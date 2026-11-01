## Agent notes

### Verify

`./build.ps1 -Task All` is the one check, same as CI (PSScriptAnalyzer, then Pester, on 5.1 and 7). A
pre-push hook runs it: enable once per clone with `git config core.hooksPath .githooks`.

To see the pages, run `./dev/Start-DevServer.ps1` (needs Pode and Pode.Web; uses fake WSUS data).

### Navigation

- `server.ps1` is layout and wiring only. Anything that decides something (what to call, what to refuse,
  what to record) goes in `src/Portcullis` as a function with tests. `tests/Module.Tests.ps1` checks that
  every `*-Portcullis*` call in `server.ps1` is exported.
- The WSUS module's own rules (rings, the gate, exact-KB matching) live in that module. Call it; don't
  re-implement it. `Find-PortcullisUpdate` is the one known duplicate (see the README's next steps).
- Every function that changes a node takes a preview (except sync), calls `Assert-PortcullisPreview`, and
  writes through `Write-PortcullisAudit` on success and failure.
- Reviewing a diff: `CODING_STANDARDS.md`.

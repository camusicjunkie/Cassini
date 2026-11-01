# Coding standards

Read during review. PSScriptAnalyzer (`PSScriptAnalyzerSettings.psd1`) already enforces 5.1 syntax and
cmdlet compatibility, and rejects suppressions without a justification; this file holds only what a linter
cannot judge. Style follows the PoshCode PowerShell Practice and Style guide.

## Safety

- A function that changes a node runs only from a stored preview (`New-PortcullisPreview`), checks it with
  `Assert-PortcullisPreview`, and takes every WSUS parameter from the preview or the configuration, never
  from request data. Flag a confirm path that reads `$WebEvent.Data` for anything but the preview id.
- Every change is audited with `Write-PortcullisAudit`, on success and on failure. Flag a change path that
  can return or throw without an audit line.
- Call WSUS module functions module-qualified (`WSUS\Approve-WsusRing`), so the Microsoft
  `UpdateServices\Deny-WsusUpdate` can never be picked up instead.

## Duplication

- A check that several functions repeat lives in one private helper, with its own tests; the public tests
  assert only that the function relies on it.

## Compatibility

- Code must run on Windows PowerShell 5.1 and PowerShell 7. Flag any 7-only operator, cmdlet or parameter,
  even where the analyzer is silent.

## Suppressions

- Suppress inline with `SuppressMessageAttribute` on the smallest scope (function, not file), with a
  `Justification`. A new blanket exclusion in the settings file is a rejection.

## Surrounding style

- One function per file, file name = function name, comment-based help on every public function,
  parameter descriptions as comments above each parameter, a CHANGELOG `Unreleased` line for every
  user-visible change.

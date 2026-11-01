BeforeAll { . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\helpers\TestSetup.ps1') }
AfterAll { Remove-CassiniTestEnvironment }

# Shared helper: the only place that decides whether a preview can be confirmed. The Invoke-* tests
# only check that they call it (they refuse a wrong preview without calling WSUS).
Describe 'Assert-CassiniPreview' {
    It 'accepts a fresh preview of the right kind and id' {
        $preview = New-CassiniPreview -Kind Ring -Parameters @{}
        InModuleScope Cassini -Parameters @{ Preview = $preview } {
            { Assert-CassiniPreview -Preview $Preview -Kind Ring -PreviewId $Preview.Id -MaxAgeMinutes 15 } | Should -Not -Throw
        }
    }

    It 'refuses a preview older than the limit' {
        $preview = New-CassiniPreview -Kind Ring -Parameters @{}
        $preview.CreatedUtc = [datetime]::UtcNow.AddMinutes(-16).ToString('o')
        InModuleScope Cassini -Parameters @{ Preview = $preview } {
            { Assert-CassiniPreview -Preview $Preview -Kind Ring -PreviewId $Preview.Id -MaxAgeMinutes 15 } | Should -Throw '*more than 15 minutes old*Run the preview again*'
        }
    }

    It 'refuses <Case>' -ForEach @(
        @{ Case = 'a missing preview'; Kind = 'Ring'; UseId = $false; Message = '*no preview*' }
        @{ Case = 'the wrong kind'; Kind = 'Decline'; UseId = $true; Message = '*Ring preview, not a Decline*' }
        @{ Case = 'another id'; Kind = 'Ring'; UseId = $false; Message = '*older preview*' }
    ) {
        $preview = if ($Case -ne 'a missing preview') { New-CassiniPreview -Kind Ring -Parameters @{} }
        $id = if ($UseId) { $preview.Id } else { 'something-else' }
        InModuleScope Cassini -Parameters @{ Preview = $preview; Kind = $Kind; Id = $id; Message = $Message } {
            { Assert-CassiniPreview -Preview $Preview -Kind $Kind -PreviewId $Id -MaxAgeMinutes 15 } | Should -Throw $Message
        }
    }
}

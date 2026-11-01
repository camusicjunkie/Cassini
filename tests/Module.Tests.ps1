BeforeDiscovery {
    $publicFiles = Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\src\Cassini\Public') -Filter '*.ps1'
    $script:publicNames = @($publicFiles.BaseName)
}

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'helpers\TestSetup.ps1')
    $script:manifestPath = Join-Path -Path $PSScriptRoot -ChildPath '..\src\Cassini\Cassini.psd1'
}
AfterAll { Remove-CassiniTestEnvironment }

Describe 'Cassini module contract' {
    It 'has a valid manifest' {
        { Test-ModuleManifest -Path $script:manifestPath -ErrorAction Stop } | Should -Not -Throw
    }

    It 'pins Pode and Pode.Web as required modules' {
        $required = (Import-PowerShellDataFile -Path $script:manifestPath).RequiredModules
        ($required | Where-Object { $_.ModuleName -eq 'Pode' }).RequiredVersion | Should -Be '2.14.1'
        ($required | Where-Object { $_.ModuleName -eq 'Pode.Web' }).RequiredVersion | Should -Be '1.0.0'
        (Get-Module -Name Cassini).RequiredModules.Name | Should -Contain 'Pode.Web'
    }

    It 'exports exactly the functions in Public/' {
        $exported = @((Import-PowerShellDataFile -Path $script:manifestPath).FunctionsToExport)
        $files = @((Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\src\Cassini\Public') -Filter '*.ps1').BaseName)
        Compare-Object -ReferenceObject $files -DifferenceObject $exported | Should -BeNullOrEmpty
    }

    It '<_> has a synopsis, a description and an example' -ForEach $script:publicNames {
        $help = Get-Help -Name $_ -Full
        $help.Synopsis | Should -Not -BeNullOrEmpty
        $help.Synopsis | Should -Not -Match "^\s*$_\s"
        $help.Description | Should -Not -BeNullOrEmpty
        @($help.Examples.Example).Count | Should -BeGreaterThan 0
    }
}

Describe 'server.ps1 and dev scripts' {
    It '<_> parses without errors' -ForEach @('server.ps1', 'dev\Start-DevServer.ps1') {
        $path = Join-Path -Path $PSScriptRoot -ChildPath "..\$_"
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path -Path $path), [ref] $null, [ref] $errors)
        $errors | Should -BeNullOrEmpty
    }

    It 'server.ps1 only calls Cassini functions that the module exports' {
        $path = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\server.ps1')
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref] $null, [ref] $null)
        $called = @($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true) |
                ForEach-Object { $_.GetCommandName() } | Where-Object { $_ -like '*-Cassini*' } | Sort-Object -Unique)
        $exported = @((Import-PowerShellDataFile -Path $script:manifestPath).FunctionsToExport)

        $called | Should -Not -BeNullOrEmpty
        $called | Where-Object { $_ -notin $exported } | Should -BeNullOrEmpty
    }

    It 'the example configuration is accepted' {
        $example = Join-Path -Path $PSScriptRoot -ChildPath '..\config\cassini.example.psd1'
        (Get-CassiniConfig -Path $example).UpstreamServer | Should -Be 'wsus01.corp.local'
    }
}

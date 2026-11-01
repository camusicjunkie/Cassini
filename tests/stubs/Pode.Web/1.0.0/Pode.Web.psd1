# Stand-in for Pode.Web so Cassini's RequiredModules resolve in tests without the real module.
# Same name, version and GUID as the real one; no functions (the Cassini module never calls Pode.Web).
@{
    RootModule        = 'Pode.Web.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '5c6cae5a-8e62-48a4-c2e5-7511ffe2d439'
    Author            = 'Test stub'
    Description       = 'Test stub of Pode.Web.'
    PowerShellVersion = '5.1'
    RequiredModules   = @(
        @{ ModuleName = 'Pode'; ModuleVersion = '2.13.2'; Guid = 'e3ea217c-fc3d-406b-95d5-4304ab06c6af' }
    )
    FunctionsToExport = @()
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}

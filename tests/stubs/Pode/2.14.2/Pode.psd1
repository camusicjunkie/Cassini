# Stand-in for Pode so Cassini's RequiredModules resolve in tests without the real module.
# Same name, version and GUID as the real one; no functions (the Cassini module never calls Pode).
@{
    RootModule        = 'Pode.psm1'
    ModuleVersion     = '2.14.2'
    GUID              = 'e3ea217c-fc3d-406b-95d5-4304ab06c6af'
    Author            = 'Test stub'
    Description       = 'Test stub of Pode.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @()
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}

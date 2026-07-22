@{
    RootModule        = 'jdk-man.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'd4e5f6a7-b8c9-4d0e-af12-3456789abcde'
    Author            = 'sodekim'
    CompanyName       = 'sodekim'
    Copyright         = '(c) 2026 sodekim. All rights reserved.'
    Description       = 'Windows JDK version manager: list, use, default, add, remove.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('jdk')
    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('jdk', 'java', 'version-manager', 'windows', 'java-home')
            ProjectUri   = 'https://github.com/sodekim/jdk-man'
            LicenseUri   = 'https://github.com/sodekim/jdk-man/blob/main/LICENSE'
            ReleaseNotes = 'Initial release: list, use, default, add, remove with tab completion.'
        }
    }
}

@{
    ModuleToProcess      = 'posh-semver.psm1'
    ModuleVersion        = '0.0.1'
    CompatiblePSEditions = @('Core')
    GUID                 = '02bc1650-e68a-45f5-98aa-64703ad31ece'
    Author               = 'Ser-Drephs and contributors'
    CompanyName          = '-'
    Copyright            = '(c) Ser-Drephs and contributors.'
    Description          = 'Provides semantic versioning functions.'
    PowerShellVersion    = '7.0.0'
    FunctionsToExport    = @('Build-Changelog')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags                     = @('semver', 'semnatic versioning', 'changelog')
            LicenseUri               = 'https://github.com/ser-drephs/posh-semver/blob/main/LICENSE'
            ProjectUri               = 'https://github.com/ser-drephs/posh-semver'
            ReleaseNotes             = 'https://github.com/ser-drephs/posh-semver/blob/main/CHANGELOG.md'
            RequireLicenseAcceptance = $false
        }
    }
}

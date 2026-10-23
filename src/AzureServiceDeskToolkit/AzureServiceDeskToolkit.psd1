@{
    RootModule        = 'AzureServiceDeskToolkit.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'c2f83414-60e6-4d4c-84e5-b641d1bb9c1b'
    Author            = 'Panteleimon Tzompanakis'
    CompanyName       = 'Community'
    Copyright         = '(c) 2026 Panteleimon Tzompanakis. MIT licensed.'
    Description       = 'Read-only Microsoft Entra ID and Microsoft 365 support diagnostics.'
    PowerShellVersion = '7.4'
    FunctionsToExport = @(
        'Get-DemoSupportSnapshot'
        'Get-LiveSupportSnapshot'
        'Get-SupportDiagnosis'
        'New-SupportCaseReport'
        'Test-MicrosoftEndpoint'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('Azure', 'EntraID', 'Microsoft365', 'ServiceDesk', 'Support')
            LicenseUri = 'https://opensource.org/license/mit'
            ProjectUri = 'https://github.com/Pantelovich/azure-service-desk-toolkit'
        }
    }
}


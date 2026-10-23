[CmdletBinding(DefaultParameterSetName = 'Demo')]
param(
    [Parameter(ParameterSetName = 'Demo')]
    [switch]$Demo,

    [Parameter(Mandatory, ParameterSetName = 'Live')]
    [ValidatePattern('^[^@\s]+@[^@\s]+\.[^@\s]+$')]
    [string]$UserPrincipalName,

    [ValidatePattern('^[A-Za-z0-9-]+$')]
    [string]$CaseReference = "CASE-$(Get-Date -Format 'yyyyMMdd-HHmmss')",

    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $projectRoot 'src/AzureServiceDeskToolkit/AzureServiceDeskToolkit.psd1'
Import-Module $modulePath -Force

if (-not $OutputPath) {
    $OutputPath = Join-Path $projectRoot "reports/$CaseReference.md"
}

$snapshot = if ($PSCmdlet.ParameterSetName -eq 'Live') {
    Get-LiveSupportSnapshot -UserPrincipalName $UserPrincipalName
}
else {
    Get-DemoSupportSnapshot
}

$findings = @(Get-SupportDiagnosis -Snapshot $snapshot)
$report = New-SupportCaseReport -Snapshot $snapshot -Findings $findings -CaseReference $CaseReference -OutputPath $OutputPath

foreach ($finding in $findings) {
    $colour = switch ($finding.Severity) {
        'Critical' { 'Red' }
        'Warning'  { 'Yellow' }
        default    { 'Green' }
    }

    Write-Host "[$($finding.Severity.ToUpperInvariant())] $($finding.Category): $($finding.Message)" -ForegroundColor $colour
}

Write-Host "`nReport written to $($report.FullName)" -ForegroundColor Green


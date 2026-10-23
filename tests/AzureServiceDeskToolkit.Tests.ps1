BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../src/AzureServiceDeskToolkit/AzureServiceDeskToolkit.psd1'
    Import-Module $modulePath -Force
}

Describe 'Get-DemoSupportSnapshot' {
    It 'loads sanitised Contoso data' {
        $snapshot = Get-DemoSupportSnapshot

        $snapshot.Source | Should -Be 'Sanitised demo data'
        $snapshot.Identity.UserPrincipalName | Should -Be 'alex.wilson@contoso.example'
    }
}

Describe 'Get-SupportDiagnosis' {
    It 'identifies missing licensing, missing strong authentication and a stale sign-in' {
        $snapshot = Get-DemoSupportSnapshot
        $findings = @(Get-SupportDiagnosis -Snapshot $snapshot -Now ([datetime]'2026-10-23T10:00:00Z'))

        $findings | Where-Object { $_.Category -eq 'Licensing' } |
            Select-Object -ExpandProperty Severity | Should -Be 'Warning'
        $findings | Where-Object { $_.Category -eq 'Authentication' } |
            Select-Object -ExpandProperty Severity | Should -Be 'Warning'
        $findings | Where-Object { $_.Category -eq 'Sign-in' } |
            Select-Object -ExpandProperty Severity | Should -Be 'Warning'
    }

    It 'raises a critical finding for a disabled account' {
        $snapshot = Get-DemoSupportSnapshot
        $snapshot.Identity.AccountEnabled = $false

        $identityFinding = Get-SupportDiagnosis -Snapshot $snapshot |
            Where-Object { $_.Category -eq 'Identity' }

        $identityFinding.Severity | Should -Be 'Critical'
    }

    It 'raises a critical finding when a Microsoft endpoint is unreachable' {
        $snapshot = Get-DemoSupportSnapshot
        $snapshot.NetworkChecks[0].Succeeded = $false
        $snapshot.NetworkChecks[0].Detail = 'DNS lookup failed.'

        $connectivityFinding = Get-SupportDiagnosis -Snapshot $snapshot |
            Where-Object { $_.Category -eq 'Connectivity' -and $_.Severity -eq 'Critical' }

        $connectivityFinding.Message | Should -Match 'DNS lookup failed'
    }
}

Describe 'New-SupportCaseReport' {
    It 'writes an escalation-ready Markdown report' {
        $snapshot = Get-DemoSupportSnapshot
        $findings = @(Get-SupportDiagnosis -Snapshot $snapshot -Now ([datetime]'2026-10-23T10:00:00Z'))
        $path = Join-Path $TestDrive 'CASE-1001.md'

        $result = New-SupportCaseReport -Snapshot $snapshot -Findings $findings -CaseReference 'CASE-1001' -OutputPath $path
        $content = Get-Content -LiteralPath $result.FullName -Raw

        $content | Should -Match '# Support case CASE-1001'
        $content | Should -Match 'alex.wilson@contoso.example'
        $content | Should -Match '## Escalation note'
        $content | Should -Match 'No account changes were made'
    }
}


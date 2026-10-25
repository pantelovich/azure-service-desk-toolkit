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

    It 'does not treat a recent failed-attempt timestamp as successful access' {
        $snapshot = Get-DemoSupportSnapshot
        $snapshot.Identity | Add-Member -NotePropertyName LastSignInDateTime -NotePropertyValue '2026-10-22T10:00:00Z'
        $snapshot.Identity.PSObject.Properties.Remove('LastSuccessfulSignInDateTime')

        $finding = Get-SupportDiagnosis -Snapshot $snapshot -Now ([datetime]'2026-10-23T10:00:00Z') |
            Where-Object Category -eq 'Sign-in'

        $finding.Severity | Should -Be 'Warning'
        $finding.Message | Should -Match 'No successful sign-in timestamp is available'
    }

    It 'handles null successful sign-in data as unknown' {
        $snapshot = Get-DemoSupportSnapshot
        $snapshot.Identity.LastSuccessfulSignInDateTime = $null

        $finding = Get-SupportDiagnosis -Snapshot $snapshot |
            Where-Object Category -eq 'Sign-in'

        $finding.Severity | Should -Be 'Warning'
    }
}

Describe 'Get-LiveSupportSnapshot sign-in data' {
    It 'maps the successful field and ignores a recent failed attempt' {
        InModuleScope AzureServiceDeskToolkit {
            function Connect-MgGraph {}
            function Invoke-MgGraphRequest {}
            Mock Connect-MgGraph {}
            Mock Test-MicrosoftEndpoint {
                param($HostName)
                [pscustomobject]@{
                    Name      = $HostName
                    Succeeded = $true
                    Detail    = 'ok'
                }
            }
            Mock Invoke-MgGraphRequest {
                param($Method, $Uri)
                $Method | Should -Be 'GET'
                if ($Uri -match '/licenseDetails') {
                    return @{ value = @() }
                }
                if ($Uri -match '/authentication/methods') {
                    return @{ value = @() }
                }
                if ($Uri -match '/healthOverviews') {
                    return @{ value = @() }
                }
                return @{
                    id                = 'user-1'
                    displayName       = 'Alex'
                    userPrincipalName = 'alex@contoso.example'
                    accountEnabled    = $true
                    userType          = 'Member'
                    department        = 'Operations'
                    jobTitle          = 'Coordinator'
                    createdDateTime   = '2025-01-01T00:00:00Z'
                    signInActivity    = @{
                        lastSignInDateTime           = '2026-10-22T10:00:00Z'
                        lastSuccessfulSignInDateTime = '2025-01-01T00:00:00Z'
                    }
                }
            }

            $snapshot = Get-LiveSupportSnapshot -UserPrincipalName 'alex@contoso.example'
            $snapshot.Identity.LastSuccessfulSignInDateTime | Should -Be '2025-01-01T00:00:00Z'
            $finding = Get-SupportDiagnosis -Snapshot $snapshot | Where-Object Category -eq 'Sign-in'
            $finding.Severity | Should -Be 'Warning'
        }
    }

    It 'handles missing sign-in activity without a strict-mode error' {
        InModuleScope AzureServiceDeskToolkit {
            function Connect-MgGraph {}
            function Invoke-MgGraphRequest {}
            Mock Connect-MgGraph {}
            Mock Test-MicrosoftEndpoint {
                param($HostName)
                [pscustomobject]@{
                    Name      = $HostName
                    Succeeded = $true
                    Detail    = 'ok'
                }
            }
            Mock Invoke-MgGraphRequest {
                param($Method, $Uri)
                $Method | Should -Be 'GET'
                if ($Uri -match '/licenseDetails') {
                    return @{ value = @() }
                }
                if ($Uri -match '/authentication/methods') {
                    return @{ value = @() }
                }
                if ($Uri -match '/healthOverviews') {
                    return @{ value = @() }
                }
                return @{
                    id                = 'user-1'
                    displayName       = 'Alex'
                    userPrincipalName = 'alex@contoso.example'
                    accountEnabled    = $true
                    userType          = 'Member'
                    department        = 'Operations'
                    jobTitle          = 'Coordinator'
                    createdDateTime   = '2025-01-01T00:00:00Z'
                }
            }

            $snapshot = Get-LiveSupportSnapshot -UserPrincipalName 'alex@contoso.example'
            $snapshot.Identity.LastSuccessfulSignInDateTime | Should -BeNullOrEmpty
        }
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
        $content | Should -Match 'Last successful sign-in: 2026-08-28T16:42:00(\.0+)?Z'
        $content | Should -Match '## Escalation note'
        $content | Should -Match 'No account changes were made'
    }

    It 'reports unavailable successful sign-in data as unknown' {
        $snapshot = Get-DemoSupportSnapshot
        $snapshot.Identity.LastSuccessfulSignInDateTime = $null
        $findings = @(Get-SupportDiagnosis -Snapshot $snapshot)
        $path = Join-Path $TestDrive 'CASE-1002.md'

        $result = New-SupportCaseReport -Snapshot $snapshot -Findings $findings -CaseReference 'CASE-1002' -OutputPath $path
        $content = Get-Content -LiteralPath $result.FullName -Raw

        $content | Should -Match 'Last successful sign-in: Unknown'
        $content | Should -Match 'No successful sign-in timestamp is available'
    }
}


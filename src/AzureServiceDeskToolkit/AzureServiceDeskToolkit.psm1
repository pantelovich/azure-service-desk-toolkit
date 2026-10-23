Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-SupportFinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Pass', 'Warning', 'Critical')]
        [string]$Severity,

        [Parameter(Mandatory)]
        [string]$Category,

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter(Mandatory)]
        [string]$NextAction
    )

    [pscustomobject]@{
        Severity   = $Severity
        Category   = $Category
        Message    = $Message
        NextAction = $NextAction
    }
}

function Test-MicrosoftEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$HostName,

        [ValidateRange(1, 65535)]
        [int]$Port = 443,

        [ValidateRange(1, 30)]
        [int]$TimeoutSeconds = 5
    )

    $result = [ordered]@{
        Name      = $HostName
        Succeeded = $false
        Detail    = ''
    }

    try {
        $addresses = [System.Net.Dns]::GetHostAddresses($HostName)
        if ($addresses.Count -eq 0) {
            throw 'DNS returned no addresses.'
        }

        $client = [System.Net.Sockets.TcpClient]::new()
        try {
            $task = $client.ConnectAsync($HostName, $Port)
            if (-not $task.Wait([TimeSpan]::FromSeconds($TimeoutSeconds))) {
                throw "TCP connection timed out after $TimeoutSeconds seconds."
            }

            $task.GetAwaiter().GetResult()
            $result.Succeeded = $true
            $result.Detail = "DNS resolved to $($addresses[0]); TCP $Port connected."
        }
        finally {
            $client.Dispose()
        }
    }
    catch {
        $result.Detail = $_.Exception.Message
    }

    [pscustomobject]$result
}

function Get-DemoSupportSnapshot {
    [CmdletBinding()]
    param(
        [string]$Path = (Join-Path $PSScriptRoot '../../examples/demo-user.json')
    )

    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        throw "Demo snapshot was not found: $resolvedPath"
    }

    Get-Content -LiteralPath $resolvedPath -Raw | ConvertFrom-Json -Depth 20
}

function Get-LiveSupportSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[^@\s]+@[^@\s]+\.[^@\s]+$')]
        [string]$UserPrincipalName
    )

    if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue)) {
        throw 'Microsoft.Graph.Authentication is required. Run: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser'
    }

    $scopes = @(
        'User.Read.All'
        'Directory.Read.All'
        'UserAuthenticationMethod.Read.All'
        'AuditLog.Read.All'
        'ServiceHealth.Read.All'
    )

    Connect-MgGraph -Scopes $scopes -NoWelcome

    $encodedUpn = [Uri]::EscapeDataString($UserPrincipalName)
    $user = Invoke-MgGraphRequest -Method GET -Uri (
        "https://graph.microsoft.com/v1.0/users/$encodedUpn" +
        '?$select=id,displayName,userPrincipalName,accountEnabled,userType,department,jobTitle,createdDateTime,signInActivity'
    )

    $licences = (Invoke-MgGraphRequest -Method GET -Uri (
        "https://graph.microsoft.com/v1.0/users/$($user.id)/licenseDetails" +
        '?$select=skuPartNumber'
    )).value

    $methods = (Invoke-MgGraphRequest -Method GET -Uri (
        "https://graph.microsoft.com/v1.0/users/$($user.id)/authentication/methods"
    )).value

    $serviceHealth = (Invoke-MgGraphRequest -Method GET -Uri (
        'https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/healthOverviews' +
        '?$select=service,status'
    )).value

    $networkChecks = @(
        Test-MicrosoftEndpoint -HostName 'login.microsoftonline.com'
        Test-MicrosoftEndpoint -HostName 'graph.microsoft.com'
    )

    [pscustomobject]@{
        CollectedAt = (Get-Date).ToUniversalTime().ToString('o')
        Source      = 'Microsoft Graph'
        Identity    = [pscustomobject]@{
            DisplayName          = $user.displayName
            UserPrincipalName    = $user.userPrincipalName
            AccountEnabled       = $user.accountEnabled
            UserType             = $user.userType
            Department           = $user.department
            JobTitle             = $user.jobTitle
            CreatedDateTime      = $user.createdDateTime
            LastSignInDateTime   = $user.signInActivity.lastSignInDateTime
        }
        Licences              = @($licences | ForEach-Object { $_.skuPartNumber })
        AuthenticationMethods = @($methods | ForEach-Object { $_.'@odata.type'.Split('.')[-1] })
        NetworkChecks         = @($networkChecks)
        ServiceHealth         = @($serviceHealth)
    }
}

function Get-SupportDiagnosis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject]$Snapshot,

        [datetime]$Now = (Get-Date)
    )

    process {
        $findings = [System.Collections.Generic.List[object]]::new()

        if ($Snapshot.Identity.AccountEnabled) {
            $findings.Add((New-SupportFinding -Severity Pass -Category 'Identity' -Message 'The account is enabled.' -NextAction 'Continue with licence, authentication and service checks.'))
        }
        else {
            $findings.Add((New-SupportFinding -Severity Critical -Category 'Identity' -Message 'The account is blocked from signing in.' -NextAction 'Confirm the disablement is expected before escalating to an authorised identity administrator.'))
        }

        if (@($Snapshot.Licences).Count -gt 0) {
            $findings.Add((New-SupportFinding -Severity Pass -Category 'Licensing' -Message "Assigned licences: $(@($Snapshot.Licences) -join ', ')." -NextAction 'Confirm the required service plan is enabled if the application still fails.'))
        }
        else {
            $findings.Add((New-SupportFinding -Severity Warning -Category 'Licensing' -Message 'No Microsoft 365 licence is assigned.' -NextAction 'Check the joiner or licence request and escalate for approval before assigning a licence.'))
        }

        $strongMethods = @($Snapshot.AuthenticationMethods | Where-Object {
            $_ -notin @('passwordAuthenticationMethod', 'emailAuthenticationMethod')
        })
        if ($strongMethods.Count -gt 0) {
            $findings.Add((New-SupportFinding -Severity Pass -Category 'Authentication' -Message "Registered strong methods: $($strongMethods -join ', ')." -NextAction 'Verify the user is selecting a registered method during sign-in.'))
        }
        else {
            $findings.Add((New-SupportFinding -Severity Warning -Category 'Authentication' -Message 'No strong authentication method was found.' -NextAction 'Check the tenant registration policy and guide the user through the approved MFA registration process.'))
        }

        if ($Snapshot.Identity.LastSignInDateTime) {
            $lastSignIn = [datetime]$Snapshot.Identity.LastSignInDateTime
            $daysSinceSignIn = [math]::Floor(($Now.ToUniversalTime() - $lastSignIn.ToUniversalTime()).TotalDays)
            if ($daysSinceSignIn -gt 30) {
                $findings.Add((New-SupportFinding -Severity Warning -Category 'Sign-in' -Message "The last successful sign-in was $daysSinceSignIn days ago." -NextAction 'Confirm whether the account is still required and review recent sign-in logs before changing access.'))
            }
            else {
                $findings.Add((New-SupportFinding -Severity Pass -Category 'Sign-in' -Message "A successful sign-in was recorded $daysSinceSignIn days ago." -NextAction 'Compare the working sign-in with the current device, network and application.'))
            }
        }

        foreach ($check in @($Snapshot.NetworkChecks)) {
            if ($check.Succeeded) {
                $findings.Add((New-SupportFinding -Severity Pass -Category 'Connectivity' -Message "$($check.Name): $($check.Detail)" -NextAction 'No endpoint connectivity action is required.'))
            }
            else {
                $findings.Add((New-SupportFinding -Severity Critical -Category 'Connectivity' -Message "$($check.Name): $($check.Detail)" -NextAction 'Check DNS, proxy, firewall and local network configuration before escalating.'))
            }
        }

        foreach ($service in @($Snapshot.ServiceHealth)) {
            if ($service.Status -ne 'serviceOperational') {
                $findings.Add((New-SupportFinding -Severity Warning -Category 'Service health' -Message "$($service.Service) reports $($service.Status)." -NextAction 'Check the Microsoft 365 admin centre incident details and link the case if symptoms match.'))
            }
        }

        @($findings)
    }
}

function New-SupportCaseReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Snapshot,

        [Parameter(Mandatory)]
        [object[]]$Findings,

        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9-]+$')]
        [string]$CaseReference,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $outputDirectory = Split-Path -Parent $OutputPath
    if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }

    $severityOrder = @{ Critical = 0; Warning = 1; Pass = 2 }
    $orderedFindings = $Findings | Sort-Object { $severityOrder[$_.Severity] }, Category
    $criticalCount = @($Findings | Where-Object Severity -eq 'Critical').Count
    $warningCount = @($Findings | Where-Object Severity -eq 'Warning').Count
    $passCount = @($Findings | Where-Object Severity -eq 'Pass').Count

    $collectedAt = if ($Snapshot.CollectedAt -is [datetime]) {
        $Snapshot.CollectedAt.ToUniversalTime().ToString('o')
    }
    else {
        [string]$Snapshot.CollectedAt
    }
    $lastSignIn = if ($Snapshot.Identity.LastSignInDateTime -is [datetime]) {
        $Snapshot.Identity.LastSignInDateTime.ToUniversalTime().ToString('o')
    }
    else {
        [string]$Snapshot.Identity.LastSignInDateTime
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# Support case $CaseReference")
    $lines.Add('')
    $lines.Add("Generated: $collectedAt")
    $lines.Add("Source: $($Snapshot.Source)")
    $lines.Add('')
    $lines.Add('## User and account')
    $lines.Add('')
    $lines.Add("- Display name: $($Snapshot.Identity.DisplayName)")
    $lines.Add("- User principal name: $($Snapshot.Identity.UserPrincipalName)")
    $lines.Add("- Account enabled: $($Snapshot.Identity.AccountEnabled)")
    $lines.Add("- Department: $($Snapshot.Identity.Department)")
    $lines.Add("- Job title: $($Snapshot.Identity.JobTitle)")
    $lines.Add("- Last successful sign-in: $lastSignIn")
    $lines.Add('')
    $lines.Add('## Triage summary')
    $lines.Add('')
    $lines.Add("- Critical: $criticalCount")
    $lines.Add("- Warning: $warningCount")
    $lines.Add("- Passed: $passCount")
    $lines.Add('')
    $lines.Add('## Findings and next actions')
    $lines.Add('')

    foreach ($finding in $orderedFindings) {
        $lines.Add("### [$($finding.Severity.ToUpperInvariant())] $($finding.Category)")
        $lines.Add('')
        $lines.Add($finding.Message)
        $lines.Add('')
        $lines.Add("Next action: $($finding.NextAction)")
        $lines.Add('')
    }

    $lines.Add('## Escalation note')
    $lines.Add('')
    $lines.Add('Account state, licensing, authentication registration, Microsoft service health and endpoint connectivity were checked. No account changes were made. Review the warning and critical findings above before assigning the case.')
    $lines.Add('')
    $lines.Add('## Data handling')
    $lines.Add('')
    $lines.Add('This report may contain personal data. Store it only in the approved ticketing or support system and follow the organisation retention policy.')

    Set-Content -LiteralPath $OutputPath -Value $lines -Encoding utf8
    Get-Item -LiteralPath $OutputPath
}

Export-ModuleMember -Function @(
    'Get-DemoSupportSnapshot'
    'Get-LiveSupportSnapshot'
    'Get-SupportDiagnosis'
    'New-SupportCaseReport'
    'Test-MicrosoftEndpoint'
)


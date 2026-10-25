# Azure Service Desk Toolkit

A read-only PowerShell tool for gathering evidence about Microsoft 365 sign-in support cases. It checks account state, licences, authentication methods, the last successful sign-in, Microsoft service health and DNS/TCP connectivity. It writes a Markdown case report with suggested next steps.

## Demo

Requires PowerShell 7.4 or newer. The demo reads the fixed, fictional data in `examples/demo-user.json`, including its network results. It does not contact Microsoft Graph or run live network checks.

```powershell
pwsh ./scripts/Invoke-SupportSnapshot.ps1 -Demo -CaseReference CASE-1001
```

The report is saved to `reports/CASE-1001.md`. See [`examples/example-report.md`](examples/example-report.md) for an example.

## Live collection

Live mode uses Microsoft Graph delegated access and interactive analyst sign-in. The signed-in analyst needs the required permissions, consent and tenant entitlements. See [`docs/graph-permissions.md`](docs/graph-permissions.md) for the permission details. Collection stops if a Graph request fails, so it does not produce a partial report.

Install `Microsoft.Graph.Authentication`, then run the command from the authorised analyst computer:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
pwsh ./scripts/Invoke-SupportSnapshot.ps1 -UserPrincipalName user@yourtenant.example -CaseReference INC-1042
```

Network checks describe the computer running the script. They test DNS resolution and TCP connection to Microsoft's login and Graph endpoints. They do not prove that sign-in works.

To check an employee laptop's network path without Graph access, import the module and run only the endpoint function:

```powershell
Import-Module ./src/AzureServiceDeskToolkit/AzureServiceDeskToolkit.psd1
Test-MicrosoftEndpoint -HostName login.microsoftonline.com
Test-MicrosoftEndpoint -HostName graph.microsoft.com
```

The snapshot field `LastSuccessfulSignInDateTime` is sourced from Graph's `signInActivity.lastSuccessfulSignInDateTime`. Graph may omit this value. An absent timestamp means the toolkit cannot assess sign-in recency.

For the collection flow and report handling, see [`docs/how-it-works.md`](docs/how-it-works.md).

## Support workflow

1. Confirm the affected user, symptom and time. Importing the module only loads its functions. It does not connect to Graph.
2. Run the live collection command above. It signs in to Graph, collects account data and runs network checks on the analyst computer. It then checks the snapshot and writes a report.
3. Test DNS and TCP on the employee's laptop using the separate endpoint commands. Add those results to the case and identify the computer tested.
4. Investigate the findings, make the approved repair and test the affected service with the user. Add the action, outcome and remaining work to the ticket.

The current rules check account enabled state, assigned licence names, registered authentication methods, the age of the last successful sign-in, service status and endpoint connectivity. They do not check subscription expiry, individual failed sign-ins or sign-ins outside an approved region. The report contains findings and next actions. The technician records the repair and confirmed outcome.

## Azure template

The optional Bicep deployment creates a resource group, a Blob container and a Log Analytics workspace. The storage account disables shared-key access and public Blob access, but its public network endpoint is enabled. The toolkit does not upload reports or send data to Log Analytics. Review the deployment before use because Azure resources may incur charges.

```powershell
az login
az deployment sub what-if --location uksouth --template-file infra/main.bicep --parameters infra/main.bicepparam
```

## Checks

Requires Pester, PSScriptAnalyzer and the Bicep CLI for the full checks.

```powershell
make lint
make test
make bicep
```

GitHub Actions runs these checks on pushes and pull requests.

## Limits and safety

- The toolkit gathers evidence only. It does not change accounts, licences or authentication methods.
- Live collection requires tenant access and can fail when a Graph request is unavailable or not authorised.
- Connectivity results describe the machine that ran the checks.
- Reports can contain personal data. Store them only in an organisation-approved support system.
- Intune device compliance and endpoint-management checks are not included.

## Project layout

```text
src/             PowerShell module
scripts/         Command-line entry point
examples/        Fictional demo data and sample report
tests/           Pester tests
infra/           Optional Azure Bicep templates
docs/            Permissions, workflow and support scenario
reports/         Locally generated reports
```

## Licence

MIT

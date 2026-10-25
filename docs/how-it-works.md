# How the toolkit works

## Where to run it

There are two different sources of evidence.

| Check | Where to run it | Graph sign-in needed? |
|---|---|---|
| Account, licence, authentication and Microsoft service checks | An authorised analyst computer | Yes |
| The employee's DNS and TCP connection | The employee's laptop, directly or through an approved remote session | No |
| Demo | Any computer with PowerShell 7.4 or newer | No |

The complete live script currently does both cloud collection and local network checks. If you run it from your Mac, its network results describe your Mac. Keep the laptop's separate test results in the case notes and label their source. Do not give an employee Graph permissions just to test their connection.

From the project folder on a test laptop, these commands use only the exported network function:

```powershell
Import-Module ./src/AzureServiceDeskToolkit/AzureServiceDeskToolkit.psd1
Test-MicrosoftEndpoint -HostName login.microsoftonline.com
Test-MicrosoftEndpoint -HostName graph.microsoft.com
```

This resolves each name and attempts TCP port 443. Success does not prove that HTTPS, a password, MFA or the application works.

## What Microsoft Graph means

Microsoft Graph is Microsoft's API for Microsoft 365 and Entra data. An API lets software request information in a defined format. A technician can read an account in an admin portal. This script requests related information through Graph and receives JSON data.

The script uses delegated access. You sign in as the analyst, the SDK obtains an access token and Graph checks the requested permissions and your access. The employee whose account you inspect is a separate target. Signing into Windows as a local administrator does not grant Microsoft Graph access. [Graph authentication](https://learn.microsoft.com/en-us/graph/auth/auth-concepts)

The script calls `Connect-MgGraph`, then `Invoke-MgGraphRequest -Method GET`. GET requests read data. Other Graph methods can change data, but this toolkit does not call them. The SDK handles authentication rather than the script asking you to put a password or client secret in a file.

Use the work account for the target organisation. See [Graph permissions](graph-permissions.md) for consent, role and licence requirements. Do not upload the script into the admin website to give it access.

## A complete run

1. You start `Invoke-SupportSnapshot.ps1` with a case reference. Supplying `-UserPrincipalName` selects live mode. Otherwise it uses the demo parameter set.
2. The script imports the module described by the `.psd1` manifest.
3. Demo mode reads the fictional JSON fixture. Live mode signs in and reads the user, licence details, registered methods and service health from Graph, then runs the local network checks.
4. Both modes produce a snapshot with the same expected structure.
5. The diagnosis function turns that snapshot into findings with a severity, category, message and next action.
6. The report function writes those findings to a local Markdown file. The entry script also prints them to the terminal.

Demo mode's account, service and network values are fixed examples. They are not fresh observations. Live Graph errors currently stop collection instead of producing a report with partial data.

## All functions

| Function | What it does |
|---|---|
| `New-SupportFinding` | Internal helper. Creates a consistent object containing `Severity`, `Category`, `Message` and `NextAction`. |
| `Test-MicrosoftEndpoint` | Resolves a hostname with .NET DNS, opens a .NET TCP client and attempts the specified port. Default port is 443. It limits the TCP wait, catches errors and disposes of the client. It returns `Name`, `Succeeded` and `Detail`. The TCP timeout is not a deadline for the preceding DNS lookup. |
| `Get-DemoSupportSnapshot` | Checks that the fixture file exists, reads its text and converts JSON into PowerShell objects. |
| `Get-LiveSupportSnapshot` | Checks for the Graph authentication command, signs in, URL-encodes the target username and makes GET requests. It maps the responses and local network checks into one snapshot. |
| `Get-SupportDiagnosis` | Checks enabled state, licence presence, authentication-method registration, successful sign-in age, endpoint results and non-operational service status. It returns findings, not a confirmed root cause or an automatic fix. |
| `New-SupportCaseReport` | Creates the output directory if needed, sorts findings by severity, counts them, writes account details and next actions, and returns the report file. |

The last five functions are exported. The finding helper is internal. The command-line script coordinates them but does not define another function.

## From report to resolved ticket

`Import-Module` loads the functions without connecting to Graph. The live entry script calls the collector, which connects to Graph and gathers the data. The snapshot is a PowerShell object containing that evidence, not a screenshot or a backup.

The rules can flag a disabled account, no assigned licence, no recognised strong authentication method, an old or unknown successful sign-in, a service advisory or a failed endpoint check. This version does not inspect individual failed sign-ins, subscription expiry or permitted countries.

The generated report is the initial evidence. The technician adds separately collected laptop results, investigates the likely cause and carries out an approved repair. The final ticket records what changed and whether the user can use the affected service. A report alone does not mean the incident is resolved.

## Important PowerShell commands

| Command or feature | Purpose here |
|---|---|
| `Import-Module` | Loads the module and its exported functions. |
| `Get-Content -Raw` and `ConvertFrom-Json` | Read the entire fixture and turn it into structured objects. |
| `Connect-MgGraph` | Authenticates the analyst and requests delegated permissions. |
| `Invoke-MgGraphRequest` | Issues the Graph GET requests. |
| `ForEach-Object` | Extracts values such as licence product codes and authentication-method names. |
| `Where-Object` | Selects findings or methods matching a condition. |
| `Sort-Object` | Puts critical findings before warnings and passes. |
| `Set-Content` and `Get-Item` | Write the report and return information about its file. |
| `Set-StrictMode` and `$ErrorActionPreference` | Expose coding mistakes and make supported errors terminate rather than silently continuing. |
| `try`, `catch`, `finally` | Handle failures and release the TCP client even when a connection fails. |

## Files you should be able to explain

| File | Purpose |
|---|---|
| `README.md` | Short introduction, run commands and limits. |
| `scripts/Invoke-SupportSnapshot.ps1` | Entry point and parameter validation. Chooses collection mode and joins the functions together. |
| `src/AzureServiceDeskToolkit/AzureServiceDeskToolkit.psd1` | Module manifest. Declares the root module, minimum PowerShell version, version and exported functions. |
| `src/AzureServiceDeskToolkit/AzureServiceDeskToolkit.psm1` | Implementation of the six functions above. |
| `examples/demo-user.json` | Fictional, repeatable snapshot input. |
| `examples/example-report.md` | Sample output from that fictional input. |
| `tests/AzureServiceDeskToolkit.Tests.ps1` | Pester tests for parsing, diagnosis, report generation and successful sign-in handling. Graph and network collection are mocked in regression tests. |
| `Makefile` | Shortcuts for demo, tests, analysis and Bicep compilation. |
| `.github/workflows/ci.yml` | Runs PowerShell checks/tests and Bicep compilation in GitHub Actions. It does not deploy infrastructure. |
| `infra/main.bicep` | Subscription-scope template. Defines a tagged resource group and calls the storage/logging module. |
| `infra/main.bicepparam` | Example values supplied to the deployment template. |
| `infra/modules/support-evidence.bicep` | Defines the storage account, report container and Log Analytics workspace. |
| `docs/graph-permissions.md` | How Graph access is authorised and what this version requests. |
| `docs/support-scenario.md` | One fictional case from symptom to handover. |
| `docs/adr/001-support-snapshot-first.md` | The reason for a read-only first release. |
| `.editorconfig` | Consistent encoding, indentation and line endings. |
| `.gitignore` | Keeps reports, tokens, local notes and tooling state out of the public source. |
| `LICENSE` | MIT licence for the source code, not a Microsoft 365 product licence. |

Files under `reports/` are local generated output. Local project instruction/planning notes are not part of the program.

## Results you must interpret correctly

- The successful sign-in field is `signInActivity.lastSuccessfulSignInDateTime`. `lastSignInDateTime` can include failed attempts. A missing successful timestamp is reported as unknown, not as a successful login. [Microsoft field definitions](https://learn.microsoft.com/en-us/graph/api/resources/signinactivity?view=graph-rest-1.0)
- An enabled account can still be stopped by other access controls. It is not proof of access to every application.
- A licence being present is not proof that the required Exchange or Teams service plan is enabled or provisioned.
- The method classifier is simple. Registered methods do not prove that a particular MFA challenge or policy succeeded.
- A Microsoft service status is another clue. It is not proof that the employee has the same incident.
- The optional Blob container blocks anonymous access, but the account's public network endpoint remains enabled. It is not a private endpoint design.
- There is no automatic upload to Blob or ingestion into Log Analytics. The current script writes a local report.

## Why the project is useful

The design separates collection, diagnosis and reporting so a technician can test the rules with fictional inputs. It provides an evidence-gathering starting point and a consistent handover. The technician still confirms impact, chooses an authorised action and tests the affected service.

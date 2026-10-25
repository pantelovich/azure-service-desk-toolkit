# Microsoft Graph access

Graph is Microsoft's API for cloud account and service information. This toolkit uses delegated access through the Microsoft Graph PowerShell SDK. It acts on behalf of a signed-in analyst. It does not use an unattended application identity, a client secret or the employee's password.

## Who signs in?

Run live collection on an authorised support computer and sign in with the organisation's approved work account. The target username is the employee whose information you want to inspect. It is not necessarily the account signing in.

An employee's laptop needs no Graph access for DNS/TCP testing. Import the module and use `Test-MicrosoftEndpoint` on that laptop. Keep privileged account collection separate from the endpoint test.

## Permissions requested by this version

| Delegated scope | Use |
|---|---|
| `User.Read.All` | Read the target user and account properties. |
| `Directory.Read.All` | Directory reads, including the licence-details request. This is a broad scope, not a claim that every directory permission is required for the task. |
| `UserAuthenticationMethod.Read.All` | Read the registered authentication methods for the target user. |
| `AuditLog.Read.All` | Access sign-in activity, subject to the applicable licence and role requirements. |
| `ServiceHealth.Read.All` | Read Microsoft service health for the tenant. |

These scopes do not request account, group, licence or authentication write access. They still expose organisational data and need admin consent if that consent is not already in place. An authorised tenant administrator reviews the requested application and permissions through the organisation's consent process. Do not grant blanket access to an employee account to make the script run. [Graph access model](https://learn.microsoft.com/en-us/graph/auth/auth-concepts)

The current permission set can be narrowed after checking the required endpoints. For example, the licence-details API documents `LicenseAssignment.Read.All` as its least-privileged delegated scope and also accepts `User.Read.All`. Read-only does not mean the current set is the narrowest possible set. [Licence-details permissions](https://learn.microsoft.com/en-us/graph/api/user-list-licensedetails?view=graph-rest-1.0)

## Consent, roles and licences are separate

Consent approves the application's permissions. The signed-in analyst must also have the supported role or equivalent custom permission for each operation. For example, reading another user's authentication methods requires one of the documented reader/authentication roles. Consent alone does not assign that role. [Authentication-method permissions and roles](https://learn.microsoft.com/en-us/graph/api/authentication-list-methods?view=graph-rest-1.0)

Graph sign-in activity also needs the documented Entra ID P1/P2 entitlement. A free Entra tenant and Global Administrator status do not supply that paid entitlement. The current live collector requests sign-in activity and stops if a request fails. Use the fictional demo or the separate network function when live collection is unavailable. [Sign-in activity requirements](https://learn.microsoft.com/en-us/graph/api/user-list?view=graph-rest-1.0#example-11-get-users-including-their-last-sign-in-time)

## Running an approved live collection

From the project folder on the analyst computer:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
pwsh ./scripts/Invoke-SupportSnapshot.ps1 -UserPrincipalName user@company.example -CaseReference INC-1001
```

`Connect-MgGraph` opens authentication. Select the correct organisation's work account, complete the required MFA and use the approved consent route if prompted. The SDK obtains an access token and attaches it to subsequent Graph requests. The script does not need to be uploaded to an admin portal or given a secret. A company may require its own approved application registration, which would need separate configuration. [PowerShell authentication](https://learn.microsoft.com/en-us/powershell/microsoftgraph/authentication-commands?view=graph-powershell-1.0)

The SDK's default sign-in context can cache tokens across PowerShell sessions. Use an approved analyst machine and follow its session policy. `Disconnect-MgGraph` signs out of the current SDK context. Do not paste tokens into code or case notes.

## Failures to recognise

| Result | Meaning |
|---|---|
| Admin approval required | The requested consent is not approved. Follow the organisation's request process. |
| Forbidden or insufficient privileges | Check tenant, granted scopes, analyst roles and the endpoint's requirements. |
| Premium licence required | The requested API data needs an entitlement the tenant/user does not have. |
| User not found | Check the target identifier and organisation. Do not assume a deleted account from one error alone. |

No live consent or tenant permissions are changed by the demo. Generated live reports can contain personal data. Store them only in the approved support system. The committed fixture and sample report use fictional data.


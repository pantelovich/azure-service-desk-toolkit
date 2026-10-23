# Microsoft Graph permissions

Live mode asks for delegated access only. The signed-in analyst must already be allowed to read the relevant tenant information.

| Permission | Reason |
| --- | --- |
| `User.Read.All` | Read basic user and account state. |
| `Directory.Read.All` | Read assigned licence information. |
| `UserAuthenticationMethod.Read.All` | Check whether an authentication method is registered. |
| `AuditLog.Read.All` | Read the most recent successful sign-in timestamp. |
| `ServiceHealth.Read.All` | Check whether Microsoft reports an active service problem. |

The toolkit does not request user, group, licence or authentication write permissions.

## Admin consent

Some organisations require an administrator to consent to these delegated permissions. If consent is refused, stop. Do not work around the tenant policy or use a more privileged account.

## Data handling

Generated reports can contain a user's name, sign-in address and account state. Keep them in the approved ticketing system. The example fixture uses the reserved `.example` domain and contains no real person or tenant data.


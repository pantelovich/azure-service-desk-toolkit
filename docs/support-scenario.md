# Fictional support scenario

This example uses the fixed fictional data in `examples/demo-user.json`. It is not a live Microsoft 365 connection or a real employee record.

Alex Wilson reports that Outlook and Teams ask for a licence after sign-in. The fictional case reference is `CASE-1001`.

## Demo report

Run the demo with PowerShell 7.4 or newer:

```powershell
pwsh ./scripts/Invoke-SupportSnapshot.ps1 -Demo -CaseReference CASE-1001
```

The report reflects the fixture: the account is enabled, no Microsoft 365 licence is assigned, only a password method is listed, and the last successful sign-in timestamp is older than 30 days. Its service health and network results are also fixture data, not current checks.

## Example case note

In this fictional case, the missing licence is a possible explanation for the reported applications. Confirm the approved licence request and refer the case to an authorised Microsoft 365 administrator. Handle authentication-method changes through the organisation's approved process. The toolkit does not make these changes.

Assigning a licence changes access and may incur cost. First-line staff should follow the organisation's approval process and role boundaries.

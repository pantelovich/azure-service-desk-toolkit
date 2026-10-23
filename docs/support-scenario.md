# Scenario: Microsoft 365 sign-in problem

Alex reports that Outlook and Teams both ask for a licence after sign-in. The request is logged as `CASE-1001`.

## First-line check

```powershell
pwsh ./scripts/Invoke-SupportSnapshot.ps1 -Demo -CaseReference CASE-1001
```

The demo report shows:

- the account is enabled;
- no Microsoft 365 licence is assigned;
- only a password authentication method is registered;
- the last successful sign-in is older than 30 days;
- Microsoft sign-in and Graph endpoints are reachable;
- Microsoft 365 service health is operational.

## Case note

Account state, licensing, authentication registration, service health and endpoint connectivity were checked. No account changes were made. The missing licence is the most likely reason for the reported applications. Confirm the approved licence request and send the case to an authorised Microsoft 365 administrator. MFA registration should be handled separately through the organisation's approved process.

## Why this is escalated

Assigning a licence changes access and cost. First-line staff should not make that change without an approved request and the right role.


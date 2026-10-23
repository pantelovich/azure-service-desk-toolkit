# ADR 001: Start with a read-only support snapshot

Status: accepted

## Context

A first-line analyst needs enough information to separate an account problem from a device, network or Microsoft service problem. Giving a script broad write permissions would make a portfolio demo less safe and less realistic.

## Decision

The first release collects account state, assigned licences, authentication registration, recent sign-in information, Microsoft service health and basic endpoint connectivity. It then produces case notes. It does not reset passwords, enable accounts, assign licences or alter MFA methods.

Live collection uses delegated Microsoft Graph permissions and an interactive sign-in. Demo mode uses invented Contoso data and needs no tenant.

## Consequences

- The project is safe to demonstrate and useful for triage.
- A service-desk analyst still needs an authorised administrator for access changes.
- Device compliance and Intune investigation are outside the first release.


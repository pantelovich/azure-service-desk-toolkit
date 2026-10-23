.PHONY: demo test lint bicep

demo:
	pwsh ./scripts/Invoke-SupportSnapshot.ps1 -Demo -CaseReference CASE-1001 -OutputPath ./reports/CASE-1001.md

test:
	pwsh -NoProfile -Command "Invoke-Pester -Path ./tests -CI -Output Detailed"

lint:
	pwsh -NoProfile -Command "\$$results = @(); \$$results += Invoke-ScriptAnalyzer -Path ./src -Recurse -Severity Error; \$$results += Invoke-ScriptAnalyzer -Path ./scripts -Recurse -Severity Error; \$$results | Format-Table; if (\$$results) { throw 'PSScriptAnalyzer found errors.' }"

bicep:
	az bicep build --file ./infra/main.bicep --outfile /tmp/azure-service-desk-main.json


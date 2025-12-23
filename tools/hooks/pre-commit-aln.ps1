<#
Pre-commit helper (optional): run ALN validation and conservative autofix.
Usage: copy or symlink to .git/hooks/pre-commit (Windows: .git\hooks\pre-commit)
Behavior:
 - Runs validator (read-only).
 - If validator reports missing DID or header errors, runs `fix-aln-metadata` and re-runs validator.
 - If any unflagged forbidden constructs remain, exit non-zero to refuse commit.
#>

# Run initial validation
pwsh -NoProfile -ExecutionPolicy Bypass -File ..\aln-validate\validate-aln.ps1
$rc = $LASTEXITCODE
if ($rc -ne 0) {
  Write-Output "Validation produced errors; attempting autofix for metadata..."
  pwsh -NoProfile -ExecutionPolicy Bypass -File ..\aln-fix\fix-aln-metadata.ps1
  pwsh -NoProfile -ExecutionPolicy Bypass -File ..\aln-validate\validate-aln.ps1
  $rc2 = $LASTEXITCODE
  if ($rc2 -ne 0) {
    Write-Error "ALN validation still failing after autofix. Please inspect aln-validation.json and resolve remaining issues before committing."
    exit 1
  }
}

Write-Output "ALN validation passed (or only known-flagged issues present). Proceeding with commit."
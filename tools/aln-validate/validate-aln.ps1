# Wrapper to run the repository ALN validator and produce aln-validation.json
param()

Write-Output "Running ALN validator (scripts/validator.ps1)"
try {
  & powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validator.ps1
  $code = $LASTEXITCODE
  if ($code -ne 0) { Write-Output "Validator exited with code $code"; exit $code }
} catch {
  Write-Error "Validator failed: $_"
  exit 2
}

Write-Output "Validator completed; check aln-validation.json for details."
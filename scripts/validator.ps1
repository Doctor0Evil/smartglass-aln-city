# Validator: PowerShell version of the placeholder ALN validator
# Checks for DID presence and forbidden Python-like constructs
param()

# Read canonical DID from config/did.identity.aln (fallback to hard-coded DID if not found)
$DID = 'did:ion:EiD8J2b3K8k9Q8x9L7m2n4p1q5r6s7t8u9v0w1x2y3z4A5B6C7D8E9F0'
$didConfigPath = Join-Path -Path (Get-Location) -ChildPath 'config/did.identity.aln'
if (Test-Path $didConfigPath) {
  try {
    $didContent = Get-Content -Raw -Path $didConfigPath -ErrorAction Stop
    $m = [regex]::Match($didContent, 'did:ion:[A-Za-z0-9\-:]+')
    if ($m.Success) { $DID = $m.Value }
  } catch {
    Write-Output "Warning: failed to read $didConfigPath, using default DID"
  }
}

$errors = @()
$filesChecked = @()

Write-Output "Starting ALN validation..."
$alnFiles = Get-ChildItem -Path . -Recurse -Include *.aln -File | Sort-Object FullName
if ($alnFiles.Count -eq 0) {
  Write-Output "No .aln files found."
}

foreach ($f in $alnFiles) {
  $filesChecked += $f.FullName
  $content = Get-Content -Raw -Path $f.FullName -ErrorAction Stop

  if (-not ($content -match [regex]::Escape($DID))) {
    $errors += "DID missing in $($f.FullName)"
  }

  # Skip forbidden token checks for files that have been explicitly TODO-flagged for review
  if ($content -like '*TODO(ALN-LINT)*') {
    Write-Output "Known-flagged for review: $($f.FullName) - skipping forbidden token checks"
  } else {
    if ($content -match '\bdef\s') {
      $errors += "Python 'def' found in $($f.FullName)"
    }
    if ($content -match '\bimport\s') {
      $errors += "Python 'import' found in $($f.FullName)"
    }
    if ($content -match 'pip\s+install') {
      $errors += "pip install found in $($f.FullName)"
    }
  }

  # Basic header check: file should contain keyword 'aln' near top
  $first200 = $content.Substring(0, [Math]::Min(200, $content.Length))
  if (-not ($first200 -match '^\s*aln\s')) {
    $errors += "Missing 'aln' header at top of $($f.FullName)"
  }

  Write-Output "Validated: $($f.FullName)"
}

$status = 'passed'
if ($errors.Count -gt 0) { $status = 'failed' }

$report = [PSCustomObject]@{
  status = $status
  timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  files_checked = $filesChecked
  error_count = $errors.Count
  errors = $errors
}

$report | ConvertTo-Json -Depth 5 | Out-File -FilePath "aln-validation.json" -Encoding utf8

Write-Output "Validation $status. Report written to aln-validation.json"
if ($errors.Count -gt 0) {
  Write-Output "Errors:"; Write-Output ($errors -join "`n")
  exit 1
}
exit 0

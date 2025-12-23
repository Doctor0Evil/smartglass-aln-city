<#
Idempotent ALN metadata fixer.
- Reads aln-validation.json for 'DID missing' and 'Missing 'aln' header at top' errors
- Reads canonical DID from config/did.identity.aln
- Inserts author_did into META if present, otherwise adds a minimal header with META
- Idempotent: does not insert duplicates
#>

param(
  [string]$ReportPath = "aln-validation.json"
)

if (-not (Test-Path $ReportPath)) { Write-Error "Report $ReportPath not found"; exit 2 }

$report = Get-Content -Raw -Path $ReportPath | ConvertFrom-Json

# Read DID from config
$didConfigPath = Join-Path -Path (Get-Location) -ChildPath 'config/did.identity.aln'
$DID = 'did:ion:EiD8J2b3K8k9Q8x9L7m2n4p1q5r6s7t8u9v0w1x2y3z4A5B6C7D8E9F0'
if (Test-Path $didConfigPath) {
  $didContent = Get-Content -Raw -Path $didConfigPath
  $m = [regex]::Match($didContent, 'did:ion:[A-Za-z0-9\-:]+')
  if ($m.Success) { $DID = $m.Value }
}

$didInserted = 0
$headersInserted = 0

# Collect file lists from errors
$didMissing = @()
$headerMissing = @()
foreach ($e in $report.errors) {
  if ($e -match '^DID missing in (.+)$') { $didMissing += $Matches[1] }
  if ($e -match "Missing 'aln' header at top of (.+)$") { $headerMissing += $Matches[1] }
}

# Normalize to repository paths (convert to relative where possible)
function NormalizePath([string]$full) {
  $cwd = (Get-Location).Path
  if ($full.StartsWith($cwd)) { return $full.Substring($cwd.Length+1) }
  return $full
}

# Helper: insert author_did into META or create a minimal header
function EnsureDidInFile([string]$filePath) {
  $content = Get-Content -Raw -Path $filePath -ErrorAction Stop
  if ($content -match [regex]::Escape($DID)) { return $false }

  if ($content -match '(?ms)^\s*META\b') {
    # Insert author_did after the opening META line (if not present)
    if ($content -match '(?ms)^\s*META\b(.*?)END META') {
      $metaBlock = $Matches[0]
      if ($metaBlock -match 'author_did') { return $false }
      $newMetaBlock = $metaBlock -replace '(?ms)(^\s*META\b)', "`$1\n  author_did    $DID"
      $newContent = $content -replace [regex]::Escape($metaBlock), [regex]::Escape($newMetaBlock) -replace [regex]::Escape($newMetaBlock), $newMetaBlock
      Set-Content -Path $filePath -Value $newContent -Encoding utf8
      return $true
    }
  }

  # No META block, add minimal header with META and author_did above existing content
  $basename = [System.IO.Path]::GetFileNameWithoutExtension($filePath).ToUpper()
  $header = "aln $basename`n  META`n    author_did    $DID`n  END META`n" + "`n"
  Set-Content -Path $filePath -Value ($header + $content) -Encoding utf8
  return $true
}

# Process DID missing
foreach ($f in $didMissing | Sort-Object -Unique) {
  $rel = NormalizePath $f
  if (-not (Test-Path $f)) {
    Write-Output "Skipping (not found): $rel"
    continue
  }
  $changed = EnsureDidInFile -filePath $f
  if ($changed) { Write-Output "Inserted DID into: $rel"; $didInserted++ } else { Write-Output "DID already present or added previously: $rel" }
}

# Process header missing: add minimal 'aln <BASENAME>' at top if absent
foreach ($f in $headerMissing | Sort-Object -Unique) {
  $rel = NormalizePath $f
  if (-not (Test-Path $f)) { Write-Output "Skipping (not found): $rel"; continue }
  $content = Get-Content -Raw -Path $f
  if ($content -match '(?ms)^\s*aln\b') { Write-Output "Header already present: $rel"; continue }
  $basename = [System.IO.Path]::GetFileNameWithoutExtension($f).ToUpper()
  $header = "aln $basename`n"
  Set-Content -Path $f -Value ($header + $content) -Encoding utf8
  Write-Output "Inserted header into: $rel"
  $headersInserted++
}

# Write summary
$summary = [PSCustomObject]@{
  timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  did_inserted = $didInserted
  headers_inserted = $headersInserted
}
$summary | ConvertTo-Json -Depth 5 | Out-File -FilePath "tools/aln-fix/fix-aln-metadata.report.json" -Encoding utf8

Write-Output "Fixer complete. DID inserted: $didInserted, headers inserted: $headersInserted"

if ($didInserted -gt 0 -or $headersInserted -gt 0) { exit 0 } else { exit 0 }
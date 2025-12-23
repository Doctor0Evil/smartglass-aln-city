<#
Conservative handler for forbidden Python-like constructs in .aln files.
- Reads aln-validation.json for errors referencing Python tokens
- Inserts a TODO comment above offending lines (idempotent)
- Adds a top-of-file review note (idempotent)
#>
param(
  [string]$ReportPath = "aln-validation.json"
)
if (-not (Test-Path $ReportPath)) { Write-Error "Report $ReportPath not found"; exit 2 }
$report = Get-Content -Raw -Path $ReportPath | ConvertFrom-Json

$forbiddenFiles = @{}
foreach ($e in $report.errors) {
  if ($e -match "^(Python '([^']+)' found in )(.+)$") {
    $token = $Matches[2]
    $file = $Matches[3]
    if (-not $forbiddenFiles.ContainsKey($file)) { $forbiddenFiles[$file] = @() }
    $forbiddenFiles[$file] += $token
  }
}

foreach ($pair in $forbiddenFiles.GetEnumerator()) {
  $file = $pair.Key
  $tokens = $pair.Value | Sort-Object -Unique
  if (-not (Test-Path $file)) { Write-Output "Skipping not found: $file"; continue }
  $contentLines = Get-Content -Path $file -ErrorAction Stop
  $modified = $false

  # Remove any existing markers anywhere to avoid duplicates; we'll add exactly one in the correct position
  $topMarker = "# REVIEW(ALN-LINT): Contains Python-like constructs; requires human review"
  $contentLines = $contentLines | Where-Object { $_ -notlike "*$topMarker*" }

  # Top-of-file review marker — place AFTER the 'aln' header when present to preserve header-check semantics
  $alnHeaderIndex = -1
  for ($j = 0; $j -lt [Math]::Min(12, $contentLines.Count); $j++) {
    if ($contentLines[$j] -match '^\s*aln\b') { $alnHeaderIndex = $j; break }
  }
  if ($alnHeaderIndex -ge 0) {
    # place marker immediately after the header line
    $pre = if ($alnHeaderIndex -ge 0) { $contentLines[0..$alnHeaderIndex] } else { @() }
    $post = if ($alnHeaderIndex + 1 -le $contentLines.Count - 1) { $contentLines[($alnHeaderIndex+1)..($contentLines.Count-1)] } else { @() }
    $contentLines = $pre + ,$topMarker + $post
    $modified = $true
  } else {
    # fallback: add at very top if no aln header found
    $contentLines = ,$topMarker + $contentLines
    $modified = $true
  }

  # For each token, scan lines and insert TODO comment above offending lines if not present
  foreach ($token in $tokens) {
    for ($i = 0; $i -lt $contentLines.Count; $i++) {
      if ($contentLines[$i] -match "\b$([regex]::Escape($token))\b") {
        # check previous line for existing TODO marker
        $prev = if ($i -gt 0) { $contentLines[$i-1] } else { "" }
        $todo = "# TODO(ALN-LINT): forbidden Python-like construct detected; review intent - token: $token"
        if ($prev -ne $todo) {
          $contentLines = $contentLines[0..($i-1)] + $todo + $contentLines[$i..($contentLines.Count-1)]
          $i++ # skip inserted line
          $modified = $true
        }
      }
    }
  }

  if ($modified) {
    $contentLines | Out-File -FilePath $file -Encoding utf8
    Write-Output "Flagged Python-like constructs in: $file"
  } else {
    Write-Output "No changes required for: $file"
  }
}

Write-Output "Forbidden-constructs fixer complete. Files flagged: $($forbiddenFiles.Count)"

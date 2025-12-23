# ALN Import Canonicalization Plan

This document lists ALN files containing `IMPORT`-style constructs that were flagged during linting and are candidates for canonicalization into a standard ALN DSL form.

## Goal
- Propose a conservative canonical ALN DSL form for `IMPORT` constructs so they are clearly ALN-native (not Python-like) and pass static validation.
- Preserve original intent and add comments referencing the original lines.
- Validate changes with `tools/aln-validate/validate-aln.ps1` to ensure no forbidden tokens remain.

---

## Files to review (current findings)

1) `aln/smartglass/smartglass-core.aln`
   - Current constructs (examples):
     - `IMPORT POLICY global-ethics FROM "aln/core/aln-ethical-guardrails.aln"`
     - `IMPORT FUNCTION preflight-ethical-check FROM "aln/core/aln-ethical-guardrails.aln"`
     - `IMPORT FUNCTION neuro-cyber-safety-envelope FROM "aln/core/aln-ethical-guardrails.aln"`
   - Proposed canonical forms (choose one per repo convention):
     - Option A — Explicit module binding (simple):
       - `INCLUDE "aln/core/aln-ethical-guardrails.aln" AS global-ethics
       - `USE FUNCTION preflight-ethical-check FROM global-ethics`
       - `USE FUNCTION neuro-cyber-safety-envelope FROM global-ethics`
     - Option B — Namespaced module import:
       - `MODULE global-ethics PATH "aln/core/aln-ethical-guardrails.aln"` 
       - `MODULE_FUNCTION global-ethics::preflight-ethical-check` (or `global-ethics::preflight-ethical-check` where allowed)
     - Option C — Registry + binding (if runtime supports a registry):
       - `REGISTER MODULE global-ethics FROM "aln/core/aln-ethical-guardrails.aln"` 
       - `BIND FUNCTION preflight-ethical-check TO global-ethics` 

   - Implementation notes:
     - Keep a `# ORIGINAL:` comment above the new construct referencing the previous `IMPORT` line.
     - Update `docs/aln_validator.md` and this plan with the chosen canonical form.
     - Add unit/integration checks (or a small ALN sample) to ensure runtime resolution works.

---

## Process
1. Create branch `feature/aln-import-canonicalization`.
2. For each file in scope, pick canonical form (Option A recommended for simplicity).
3. Replace original `IMPORT` lines with canonical form + `# ORIGINAL:` comment.
4. Run `pwsh -File .\tools\aln-fix\check-forbidden-constructs.ps1` and `pwsh -File .\tools\aln-validate\validate-aln.ps1` to ensure zero forbidden tokens and valid headers/DIDs.
5. Prepare a PR `feat(aln): canonicalize import constructs` listing all files and proposed changes.

---

If you approve, I'll create the branch and draft the PR summary with concrete diffs for `aln/smartglass/smartglass-core.aln` as the first pass.
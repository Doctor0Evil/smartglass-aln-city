$content = @'
# Smartglass ALN console
aln SMARTGLASS-CORE
# REVIEW(ALN-LINT): Contains Python-like constructs; requires human review
  WITHUNIFIEDSYSTEM CITY-GOV-ROOT-2025

  META
    author_did    did:ion:EiD8J2b3K8k9Q8x9L7m2n4p1q5r6s7t8u9v0w1x2y3z4A5B6C7D8E9F0
    system-name    Smartglass-ALN-Console
    version        1.1.0
    purpose        "AR/XR console for ALN-governed city and infrastructure"
    engine         "Unreal/Unity/Godot client surfaces"
    license        "Apache-2.0"
  END META

  PROFILE planner
    role            city-planner
    max-risk-score  0.35
    allow-domains   city, ai-train, smartglass
  END PROFILE

  PROFILE ops
    role            field-operator
    max-risk-score  0.20
    allow-domains   city, smartglass
  END PROFILE

  PROFILE auditor
    role            compliance-auditor
    max-risk-score  0.10
    allow-domains   city, finance, smartglass
  END PROFILE

# NOTE(ALN-LINT): The following IMPORT lines are ALN DSL imports (not Python). Please review semantics.
# TODO(ALN-LINT): forbidden Python-like construct detected; review intent - token: import
  IMPORT POLICY global-ethics FROM "aln/core/aln-ethical-guardrails.aln"
# TODO(ALN-LINT): forbidden Python-like construct detected; review intent - token: import
  IMPORT FUNCTION preflight-ethical-check FROM "aln/core/aln-ethical-guardrails.aln"
# TODO(ALN-LINT): forbidden Python-like construct detected; review intent - token: import
  IMPORT FUNCTION neuro-cyber-safety-envelope FROM "aln/core/aln-ethical-guardrails.aln"

  FUNCTION smartglass-propose-action
    INPUT
      actor-profile   PROFILE
      action-domain   Enum: city, bio, cloud, ai-train, finance, smartglass
      action-id       String
      payload         Object   # ALN-serializable proposal
      reversibility   Enum: reversible, irreversible
      risk-score      Float
      consent-model   Enum: none, explicit, regulatory
    END INPUT

    LET ethics = preflight-ethical-check(
      actor-profile,
      action-domain,
      action-id,
      reversibility,
      risk-score,
      consent-model
    )

    IF ethics != "ALLOW" THEN
      ABORT "Smartglass proposal rejected by ethical guardrails"
    ENDIF

    LET prediction = neuro-cyber-safety-envelope(
      candidate-script = payload,
      horizon          = "15m"
    )

    RETURN prediction
  END FUNCTION

  FUNCTION smartglass-apply-if-safe
    INPUT
      actor-profile   PROFILE
      action-domain   Enum: city, bio, cloud, ai-train, finance, smartglass
      action-id       String
      payload         Object
      reversibility   Enum: reversible, irreversible
      risk-score      Float
      consent-model   Enum: none, explicit, regulatory
    END INPUT

    LET prediction = smartglass-propose-action(
      actor-profile,
      action-domain,
      action-id,
      payload,
      reversibility,
      risk-score,
      consent-model
    )

    IF prediction.high_impact = true THEN
      BLOCK "Predicted impact too high; manual review required"
      EXECUTE SYSTEM auditlog \
        --validate \
        --send "/var/log/smartglass/smartglass-high-impact.log"
      RETURN { status: "PENDING_REVIEW", prediction: prediction }
    ENDIF

    EXECUTE SYSTEM sandbox-apply-change \
      --payload       payload \
      --reversible    true \
      --max-duration  "15m" \
      --log           "/var/log/smartglass/smartglass-actions.log"

    EXECUTE SYSTEM auditlog \
      --validate \
      --send "/var/log/smartglass/smartglass-ethics-commit.log"

    RETURN { status: "APPLIED", prediction: prediction }
  END FUNCTION

END aln
'@
Set-Content -Path .\aln\smartglass\smartglass-core.aln -Value $content -Encoding utf8 -Force
Write-Output "Rewrote smartglass-core.aln with cleaned content"
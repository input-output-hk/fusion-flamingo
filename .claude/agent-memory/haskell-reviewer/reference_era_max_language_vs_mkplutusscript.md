---
name: era-max-language-vs-mkplutusscript
description: cardano-ledger's AlonzoEraScript eraMaxLanguage is not authoritative for which Plutus languages mkPlutusScript actually accepts for an era
metadata:
  type: reference
---

In `cardano-ledger-alonzo`'s `AlonzoEraScript` class, `eraMaxLanguage :: Language` and `mkPlutusScript :: ... -> m (PlutusScript era)` are independent, hand-written per-era methods - `mkPlutusScript` is not derived from `eraMaxLanguage`, and the two can disagree.

Verified at `cardano-ledger-dijkstra-0.2.0.1`'s `Scripts.hs`: the `DijkstraEra` instance sets `eraMaxLanguage = PlutusV3` (line 367) but its `mkPlutusScript` (lines 369-374) has an explicit `SPlutusV4 -> pure $ DijkstraPlutusV4 plutus` arm - it accepts V4 despite `eraMaxLanguage` claiming V3 is the ceiling.

**How to apply**: when reviewing cardano-api code that adds/gates support for a Plutus language in an era (e.g. `scriptLanguageSupportedInEra`), don't infer ledger-side acceptance from `eraMaxLanguage`. Read the era's actual `mkPlutusScript` instance body in the pinned ledger version (haskdogs cache, mindful it can be stale per [[reference_verify_srp_pinned_commit]]-style caveats) to know what really succeeds vs. calls `eraUnsupportedLanguage`.

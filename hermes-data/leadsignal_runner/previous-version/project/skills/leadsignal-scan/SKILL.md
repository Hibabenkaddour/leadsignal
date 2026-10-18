---
name: leadsignal-scan
description: Execute the authorized LeadSignal batch using the current client contract.
---
# LeadSignal scan — client rules v1

Read strategy/client_rules_v1.md, icp_policy.md, signal_routing.md, source_budget.md,
deduplication.md, run_state.md, guardrails.md, supabase_schema_policy.md and contact_policy.md.
The client contract supersedes historical checkpoints and old guidance.
Keep the active ICP, exclusions, France scope, evidence quality and configured freshness.

1. Assert the worker lease and read the controller snapshot/deadlines and saved work.
2. Work on selected Apify signals first with their fixed catalog, four primary attempts
   maximum EACH. Reconcile uncertain paid requests, review cached rows and persist decisions.
   Qualify each actual employer. For cluster persist ICP pass before company follow-up;
   final proof requires three distinct complementary dated jobs, not three on the primary page.
3. Verify ICP then source, actual signal and dates. Attempt size checks; unknown size
   alone permits the documented exception, unknown identity or known exclusion does not.
4. Check EXACT full primary URL AND signal_key in existing signals. Same company or
   same event under another URL is not a duplicate. Finish the check before publication.
5. Save complete candidate evidence as ready_for_validation, call
   leadsignal_qualify_candidate, then leadsignal_publish_candidate. Read back the result.
   No numeric score. No direct inserts into publication tables. Do not publish then reject
   as a substitute for checking first. Leave history unchanged; report mistakes to operator.
6. Attempt Perplexity contacts after publication, maximum five, none required for keeping
   the opportunity. Follow the contact-finder skill and verified enrichment RPC.
7. Continue until actual deadline or genuine completed/blocked work. Non-Apify stops at
   five retained opportunities or twenty dispatched discoveries since last NEW qualification.
   A new qualified receipt resets that signal; pending candidates do not. Apify can exceed
   five by finishing qualifying paid rows, but stops new primary calls when five are reached.
8. Merge and read back checkpoint after progress. Record actual attempt IDs, source URLs,
   dates, decisions and concrete next actions. Session end is handover, not suspension.

Report retained publications out of 60 only when all twelve signals are selected;
otherwise use actual snapshot count times five. Report rejected publications separately,
contacts separately and provider costs only from actual usage. Never invent evidence.

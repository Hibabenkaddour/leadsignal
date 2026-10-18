---
name: leadsignal-contact-finder
description: Find and verify up to five contacts for an already published opportunity.
---
# Contact finder — client rules v1

Read strategy/client_rules_v1.md, contact_policy.md, supabase_schema_policy.md and guardrails.md.
Only Perplexity via perplexity_contacts.py is authorized for people/profile research.
Publish qualified business evidence first. Then attempt one bounded contact-discovery pass
and relevant exact LinkedIn verification. Zero accepted contacts never rejects an opportunity.
Never exceed five linked contacts. Prioritize current business decisions and roles relevant
to the documented opportunity; no quota-filling or invented people/roles/profile URLs.
Verify current employer, exact person URL and role through the returned source evidence.
Conflicting titles, departed employees and guessed URLs remain pending privately.
Use actual successful verification attempt IDs and finished_at timestamps in contact_research.
Enrich through leadsignal_enrich_candidate_contacts; read back opportunity_contacts.
Mark searched when the useful pass is finished, even if no person could be accepted.
Do not spend successive workers trying to reach three or five contacts; no minimum exists.
Real provider failures are recorded, not bypassed. Preserve verified existing contacts.

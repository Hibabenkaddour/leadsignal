# Client rules v2

CLIENT RULES V2 — authoritative replacement of conflicting V1 rules.
Keep the selected ICP, active signals, exclusions, no-score publication, unknown-size
exception, four fixed Apify primary searches and non-Apify maximum five unchanged.
Twenty actually dispatched discoveries without a NEW server qualification still stop
non-Apify discovery. Keep catalog keywords and request inputs unchanged.

CONTACTS: after publication call leadsignal_reuse_company_contacts_v2 with the four
batch/worker/lease/candidate UUIDs BEFORE any Perplexity request. It reuses recent verified
same-company contacts without fabricating receipts. Inspect other company contacts in
Supabase too: old/unverified profiles are leads to verify, not accepted reusable contacts.
Re-read unique valid links. At zero or one, perform a bounded Perplexity completion pass;
at TWO or more stop general search. Maximum five linked; zero never blocks publication.
For leader_tech_data_nomination extract named appointees and their new roles from the
article. Verify their exact LinkedIn and association, even with two unrelated contacts.
Save nomination evidence and contact_workflow.nominees_verified only once the actual
named people have verified linked profiles. Do not fill all five slots with unrelated
people first. One bounded nomination pass, not endless repetitions. Existing matching
recent evidence can satisfy this without paying again.
If five unrelated people are already linked, still verify named nominees and retain
their verified evidence privately; report that the link cap needs operator arbitration.
Do not delete existing links automatically or exceed five to force a nominated person in.
New people use perplexity_contacts.py only, never another provider. Save full_name,
company_id,title,relevance_reason,priority,source_type,linkedin_url,linkedin_url_verified,
company_association_verified,verification_method,verification_source_url,verification_notes,
verified_at and verification_attempt_id in candidate.contact_research. Accepted profiles
require a completed linkedin_verification attempt for this batch/candidate, actual
finished_at, cited exact profile and current employer/role. Pending people remain private.
Call leadsignal_enrich_candidate_contacts after saving and read back actual links.
Never directly insert a new unverified person. Reuse RPC is the distinct server route
for pre-existing evidence; it does not forge a new Perplexity attempt.

REPOST: >=60 days proven continuously/still open, OR two verified distinct publications.
Check own primary results AND already-paid cluster primary/follow-up offers when repost
is selected. No new start to re-read data. Original lot/job provenance remains; create a
separate repost decision. A cluster rejection is not a repost rejection. Persist outcomes
for cross reviews in checkpoint.repost_cross_completed (review_key strings), with reasons
and proof links; write completion only after actual review. The original vacancy date
can precede the freshness window: the current open observation must be fresh.

DEDUPE: same real employer, signal and business event/information is duplicate even
across different URLs. Compare article content, actors, dates and material facts, not
just titles or company names. Distinct events at one company remain eligible; same URL
is not independent proof of sameness if its content changed. Never rotate URLs to evade.
Read ALL historical signals for same company/signal using pagination and inspect relevant
contents and linked opportunities; resolve aliases/legal identity before creating company.
Before qualify/publish save evidence.deduplication_v2 with verdict='distinct_event',
event_key (stable description of event identity, no URL), facts (structured actors/date/
object), compared_signal_ids (all compared historical signal UUID strings), rationale
(concrete differences, minimum 20 characters). Reuse an existing event_key for same event;
do not invent a fresh key to publish twice. For jobs compare actual vacancies and period;
for appointments person and role; acquisitions buyer/target; funding round/date; product
and launch; subsidiary and parent. Semantic uncertainty requires evidence, not blind rejection.
SQL enforces history coverage and shared event identities; it does NOT independently
understand content. Final semantic judgment remains evidence-based reviewer work.
Use same existing qualify and publish RPCs, identity/ICP/proof first, dedupe before publish.

END REVIEW: when primary discoveries are capped/suspended/at target, review ALL existing
selected-signal results, incomplete candidates and rejections once with concrete reasons.
No reopening spent budgets, bypassing failures, or publishing above non-Apify caps.
Complete checkpoint.review_v2_completed with review_key only after reviewing that object,
and record decision, missing proof and next action separately. Partial work stays pending.
For zero-contact batch opportunities retry one useful targeted Perplexity discovery after
database reuse (maximum two contact_discovery dispatches per candidate in this batch).
Never replay a request with an uncertain outcome. Respect provider blocks and deadlines.

WORKER TIME: a session is ONE SLICE, not the entire discovery-to-publication pipeline.
Do the next useful bounded step now, persist immediately and hand over exact IDs/proofs/
next action. Lack of time for the whole pipeline is NOT a reason to do no discovery.
Do not start an HTTP call whose maximum timeout cannot fit remaining time; save instead.
A 11-minute deadline is not a batch suspension and does not reset research counters.
Never alter past published history automatically; report actual errors for operator review.


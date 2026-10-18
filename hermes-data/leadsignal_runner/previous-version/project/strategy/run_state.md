# CLIENT RULES V2 OVERRIDE

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


# Retained technical reference
# Current execution contract

Read client_rules_v1.md first. Its approved URL+signal deduplication, Apify priority,
20-dispatched-request counter reset by server qualification, five contacts maximum,
and publication order replace contradictory legacy examples below.
Legacy historical guidance is reference only, never an override.



# Run State Strategy

## Purpose and Ownership

This file defines:

- batch identity and configuration snapshots
- worker-session lifecycle
- durable research progress
- checkpointing and recovery
- publication accounting
- finalization

Follow:

- source_budget.md for targets, search coverage and allowances
- scheduled_scan_policy.md for execution windows and scheduling
- contact_policy.md for contact acceptance
- icp_policy.md for business qualification
- deduplication.md for business-event identity
- supabase_schema_policy.md for storage mappings
- reporting_policy.md for report fields
- guardrails.md for prohibited runtime actions

This file does not override those acceptance rules.

## Batch and Worker Definitions

A batch is the complete authorized research operation for a
configuration snapshot and execution window.

A worker session is one bounded Hermes execution contributing
to that batch.

One batch may require several worker sessions.

Starting a new worker conversation must not:

- create a new batch unnecessarily
- reset accepted-result counts
- discard pending candidates
- repeat completed research without a reason
- change the batch's ICP or selected signals

A worker finishing does not mean the batch target is complete.

## Execution Prerequisites

Before unattended research, the execution layer must provide:

- a persistent batch ID
- a verified configuration snapshot
- durable candidate and contact-research storage
- a durable search ledger
- worker-session tracking
- an exclusive worker lease
- heartbeat and interruption recovery
- explicit research and finalization deadlines
- tested session limits
- spending allowances
- controlled publication with duplicate and result-cap protection

Verify these capabilities instead of assuming they exist.

Markdown instructions do not implement these controls.

If required support is unavailable:

- report setup_required as a setup outcome
- identify the missing capability
- do not start an improvised unattended loop
- do not invent database columns or tables
- do not create local queues as a workaround

Use only supported storage fields and status values.

## Starting a New Batch

Before discovery:

1. Read the intended active ICP from Supabase.
2. Read hidden_signal_preferences where active = true,
   scoped to that ICP.
3. Resolve any ambiguity about the intended ICP.
4. Save the configuration snapshot and policy version.
5. Record the selected signal keys and acceptance targets.
6. Record the actual start and authorized deadlines.
7. Create the supported batch/run tracking records.
8. Acquire the worker lease before beginning research.

Do not infer configuration from:

- signal_test_runs
- previous conversations
- previous runs
- local memory
- a general request to scan

Changes to saved settings after batch creation apply to the next
batch unless the user explicitly authorizes changing this batch.

Record an authorized mid-batch change rather than silently
replacing the snapshot.

## Resuming a Batch

Load:

- batch identity and configuration snapshot
- actual remaining time and spending allowances
- selected signals and progress per signal
- accepted publication IDs
- pending candidates
- accepted and pending contact research
- search attempts and rejection reasons
- previous worker outcomes
- unresolved writes or errors

Continue from the next useful unfinished action.

Do not rely on conversation memory as the progress store.

Pending research from an earlier batch may be reconsidered,
but revalidate it against the current configuration, freshness,
deduplication and contact requirements.

Do not count an opportunity already published in an earlier batch
as a new result.

## Signal Progress

Process every selected signal across the batch.

Do not retain the old testing restriction that silently limits
the batch to five selected signals.

Work fairly across unfinished signals.
If one signal has no result, continue useful work on the others
and revisit it as required by source_budget.md.

Do not abandon a signal after its first result.

Once a signal reaches its accepted-result target, stop adding
results for it and focus on unfinished signals.

Report unsupported signals explicitly.
Do not label a signal unprocessed if any search was performed.

## Durable Research Records

Preserve progress as soon as it becomes useful.

For each candidate, retain through supported storage:

- stable candidate identity
- associated signal
- company identity
- source and event evidence
- qualification decisions
- duplicate-check outcomes
- contact research and verification
- unresolved questions
- next useful action
- publication IDs when committed

Keep business-unqualified candidates and pending contact research separate
from the normal opportunity feed.

A business-qualified candidate with all other publication requirements met
is ready even with zero, one or two accepted contacts. Publish it through
the controlled workflow and count it after successful read-back. Preserve
pending contact evidence separately for authorized enrichment.

Do not discard valid research merely because a worker ends
or contact verification is incomplete.

## Checkpointing

Checkpoint after meaningful steps, including:

- recording a search and its outcome
- accepting or rejecting candidate evidence
- verifying a contact
- resolving a duplicate
- completing a publication
- encountering a blocker
- preparing to yield

Do not wait until five opportunities are collected before saving.

Do not rely on the final conversational response to persist progress.
A hard tool-call cutoff may prevent final-response execution.

If a checkpoint write fails, report and reconcile the failure.
Do not continue indefinitely with progress stored only in memory.

## Session Limits and Yielding

Use the execution layer's verified session limits.

Do not guess Hermes configuration keys or assume the model
can observe its exact remaining tool calls.

The controller must enforce bounded worker sessions and allow
time for checkpointing and finalization.

Before a planned session limit:

- persist the latest progress
- record unfinished actions
- report the worker outcome
- release or finish the worker lease through the controller
- leave the batch resumable

A session limit is not evidence that the signal's sources
have been exhausted.

If the batch still has time and allowance, the controller may
start a fresh session to continue unfinished work.

## Unexpected Interruptions

A worker may stop because of:

- the tool-call limit
- provider errors
- process termination
- network failure
- timeout
- unavailable authentication
- database failure

Recovery must be handled by the execution layer, not solely
by instructions inside the interrupted worker.

Before retrying:

- inspect the recorded worker state
- reconcile its lease and heartbeat
- load the latest checkpoint
- check whether its last write actually committed
- retry only the unfinished operation

Use bounded retries and backoff for transient failures.

Configuration, authentication and schema failures require an
accurate blocker report rather than unlimited repeated requests.

## Overlap Protection

Only one authorized worker may hold the batch's active work lease.

Lease acquisition and renewal must be enforced atomically
by the execution layer.

Do not infer that another worker is inactive solely because:

- its run record is old
- its result count is zero
- no signals are linked yet
- its last report is missing

Do not clear all running records.

A stale lease must be reconciled with actual worker state.
Expired workers must not be able to publish after losing ownership.

If overlap cannot be resolved safely, report the uncertainty
and do not start competing work.

## Publication and Read-Back

Publish only after business qualification and all other publication
requirements pass. There is no minimum contact count. Verify every
contact that will be published; zero linked contacts is allowed.
Incomplete contact enrichment must not delay an otherwise ready publication.

Use the verified controlled publication operation.

It must protect against:

- duplicate business events
- duplicate publication after retries
- exceeding the signal's accepted-result target
- inconsistent opportunity, signal and contact links

After publication, read back and verify the committed records.

Do not increment accepted-result counts before confirmation.

If the write response is uncertain, search by stable identity
before retrying. A lost response is not proof that nothing was saved.

## Parent Run and Nouveau

Maintain one parent agent_runs record per batch and ICP
for published signal linkage.

Keep worker attempts separate through the supported
execution-tracking storage.

Link newly published signals to that parent run using
signals.agent_run_id.

Link each opportunity through opportunities.primary_signal_id.

Keep the same parent link across worker resumptions.
Do not create a different publication batch merely because
Hermes started a new conversation.

Never relink historical signals to mark old opportunities Nouveau.

## Result Accounting

Count each newly committed opportunity once in its batch.

Count each newly inserted contact row once.
Report updates separately.

Do not include historical published opportunities or contact rows
in new-insert totals.

A result saved by an earlier worker in the same batch remains
part of the batch total; do not count it again in the next worker's
new-insert total.

Track batch totals and worker deltas separately.

Candidates, searches, company records and signal records alone
are not accepted opportunity results.

Preserve confirmed counts and IDs after every publication.

## Finalization

Finish the batch when:

- all required targets are satisfied, or
- the authorized execution window ends, or
- the actual spending allowance is exhausted, or
- an unresolved blocker prevents further authorized progress

Do not extend deadlines or increase allowances autonomously.

Apply the finalization window defined by scheduled_scan_policy.md.
Do not start new discovery after its research cutoff.

Preserve pending work for possible future revalidation.
Do not manufacture completion.

Set finished_at to the actual completion timestamp.

Use only supported agent_runs.status values:

- running while the batch is active
- success when all required targets and acceptance gates are met
- partial when accepted results exist but targets remain unmet
- failed when no accepted results exist and execution ends blocked

Store detailed reasons and report outcomes in supported
logs_json or the verified execution schema.

Do not write report strings such as blocked_not_complete
into a database enum that does not support them.

## Reporting

Follow reporting_policy.md.

Keep reports concise but include actual errors and shortfalls.

Distinguish:

- worker outcome
- batch outcome
- accepted results
- pending research
- contact-verification gaps
- actual search coverage
- recovered errors
- unresolved blockers

Never report completed merely because a worker or cron invocation
finished successfully.

## Runtime Restrictions

Do not:

- use local pending/processing/results folders
- create, modify or delete local files during scans
- create temporary scripts
- use execute_code
- use old Hermes task folders or local queues
- run self-improvement
- modify instructions, schema or scheduler configuration

Use approved preinstalled tools and supported durable storage.

## Research Reliability V1 — 2026-10-06

RESEARCH RELIABILITY V1 — operator-approved execution rules, authoritative over
older ambiguous signal descriptions. Keep ICP, dates, exclusions, deduplication
and accepted-contact quality unchanged. No minimum contact count for publication.

EMPLOYMENT SIGNALS (weights are ranking values, NEVER detection thresholds):
Cluster: at least 3 distinct complementary IT/data/product vacancies at the SAME
actual hiring employer, with verified source publication dates in the last 60 days
AND within the ICP freshness window. Repeated adverts, location copies and client
assignments posted by staffing marketplaces are not proof of that platform's own
team growth. Resolve the actual employer or reject that candidate. Do not use the
alternative velocity-percentage branch without an independently evidenced baseline.
Long-open/reposted: either an offer demonstrably still open at least 60 days after
its verified original publication, OR at least 2 distinct documented publications
of the same role for the same employer. A fresh scan of the same advert is not a
republication. Copies on different sites are not independent publications.
Keep original vacancy dates separate from observed_at. Check the actual Actor's
field semantics; do NOT assume every posted_at is a scrape date or a publication date.
Keep the current triggering evidence fresh under the ICP; historical evidence may
support duration but does not make an old closed vacancy current.
Before qualification run /opt/hermes/.venv/bin/python3 /opt/data/leadsignal_runner/job_evidence.py
--schema (offline) for the exact JSON fields, then run that helper without options
with the evidence JSON on stdin. Its result
is a consistency check of your supplied evidence, not independent source verification.
Save accepted input and output in candidate.evidence.job_signal_check. Never mark
unknown fields verified just to obtain eligible=true. Preserve pending observations
using job_evidence.py --record-observation and reuse its --history output across runs.
Missing historical data means pending evidence, not an API failure. Do not invent it.

DISCOVERY SUSPENSION:
Only the controller applies the 20-dispatched-discovery-call no-progress threshold.
A worker ending its session is a handover, never a batch-wide suspension.
Save unfinished work and concrete next actions without deferred_for_batch=true.
A real operational block may use discovery_status[SIGNAL_KEY] with deferred_for_batch=true,
reason_code (provider_account_limit, provider_quota, provider_configuration,
provider_unavailable or schema_error), reason and attempt_id of an actual failed
attempt in THIS batch for THIS signal. The controller validates the failed record.
Empty results, pending evidence and session end are not provider failures or exhaustion.
Do not create dummy candidates to reset counters. Preserve all existing evidence.

TARGETED SOURCES WITHIN EXISTING ROUTES:
Appointments: exact-company newsrooms, dated IT leadership announcements, specialist press.
Subsidiaries: company announcements plus registries establishing actual parent linkage.
Office moves: regional business press and occupant newsrooms, distinguish project from move.
Public funding: named award recipients, award decisions and dated primary announcements;
discover these using the approved Tavily route, not an unapproved generic feed route.
Headcount: completed measured growth, comparable company scope and dated figures.
Internal tech recruiter: direct employer vacancies; distinguish internal hires from agency clients.
Read saved rejected events and historical duplicates BEFORE repeating investigation.

PERPLEXITY EXECUTION: a native Perplexity tool is NOT required. Use the installed
/opt/hermes/.venv/bin/python3 /opt/data/leadsignal_runner/perplexity_contacts.py
with one JSON object on stdin containing batch_id, worker_id, lease_token,
candidate_id, signal_key, purpose ('contact_discovery' or 'linkedin_verification'),
attempt_key (unique stable key), query (company identity and roles, or person/profile).
The helper validates the lease/candidate/deadline, logs start and completion itself,
calls Perplexity once, and returns answer, sources, usage and actual attempt timestamps.
Do NOT log that same request a second time. Reuse the same key after an uncertain
response: the helper returns saved completed results or refuses an uncertain replay.
Use Perplexity exclusively for contact discovery and verification. No Tavily or other
provider fallback is authorized for contacts. If Perplexity is unavailable, preserve
pending contact evidence and continue otherwise eligible opportunity publication
without contacts. Record the actual failure; never claim an unperformed request.
Check the helper with --check when needed: it reads configuration only, no provider call.
Generated answers and returned URLs are leads, NOT automatically accepted contacts.
Verify identity, current company/role and direct profile evidence under contact_policy.
Use candidate_id on all attempts and the logging timestamp for actual verification.
Never expose keys or put them in arguments or JSON inputs. Never modify installed helpers.

## Perplexity-only contacts and long-open evidence â€” 2026-10-07

CONTACTS PERPLEXITY ONLY â€” operator decision, supersedes all earlier contact routes:
Use ONLY the installed perplexity_contacts.py helper for discovery of people,
verification of their professional role/company, and exact LinkedIn profile URLs.
No Tavily/web_search, Google/RSS, Apify, web_extract or terminal HTTP fallback for
CONTACT research or profile verification. These providers retain their existing
business-event discovery/qualification routes. Do not relabel a people search as
company_qualification or source_verification to evade the restriction.
If Perplexity is unavailable, preserve verified contacts and pending evidence,
record contact_workflow.state='blocked' and the exact reason; no substitute provider.
Contact count is still not a publication gate. Perplexity text alone is not proof:
inspect the returned citations and indexed snippets, match the exact person/profile
and current company. Use purpose=linkedin_verification for acceptance evidence.
verification_attempt_id must be the successful Perplexity attempt for THIS candidate
and batch; verification_source_url must be in its returned sources. Preserve its
finished_at as verified_at. If evidence conflicts about a title, ask Perplexity to
resolve the specific conflict using dated/official sources. If unresolved, keep the
person pending; never publish a guessed title or overwrite an existing verified contact.
Do not spend the contact helper on company sector/size qualification.

QUALIFICATION CONSISTENCY:
Check exclusions (including scale-ups), actual business activity and actual employer
before contacts/publication. NAF/APE alone is insufficient evidence of present business
activity. A staffing advertiser's client vacancies do not prove growth of its own team.
Record exact sources and entity scope; unresolved eligibility is pending, not invented.
Do not revise existing opportunities or delete orphan companies automatically.
For RFPs, retain the current ICP interpretation; if the buyer fails ICP record the
candidate-specific mismatch. Do not claim all BOAMP/TED buyers or every RFP is ineligible.

LONG-OPEN OFFER EXCEPTION (tech_role_repost only):
Keep the genuine original source_published_at. Never replace it with scrape date/today.
For an old original source, publication requires evidence.long_open_proof with:
job_id, employer_company_id, original_published_at (YYYY-MM-DD), source_url (same as
event_data.source_url), original_publication_verified=true, currently_open_verified=true,
same_vacancy_verified=true, verification_attempt_id, verification_excerpt.
The verification attempt must be a successful source_verification for THIS candidate,
batch and job URL, finished during this batch. result_summary.job_observation must
record matching job_id, employer_company_id, original_published_at, source_url,
original_publication_verified=true, currently_open_verified=true, same_vacancy_verified=true,
and a nonempty excerpt from the actual observed source. Observation must prove still open.
At least 60 days must separate original publication from the verification date.
event_date may be null or the original publication date; never invent a new event date.
Only use this exception after SQL migration has been installed. Other signal freshness
checks stay unchanged. Record job_evidence.py output as a consistency check, not final
publication approval. The server checks the supporting attempt; generic eligible=true
alone is insufficient. Company qualification and deduplication still apply.

REPORTING: Always report published signals / ALL snapshot-selected signals, including
suspended ones in the denominator. A suspended signal is not achieved or removed.
Use controller timestamps, not a guessed wall-clock report time. Report contact work
remaining/blocked separately; fewer than three contacts is not automatically pending.



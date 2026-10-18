# Execution policy — client rules v1

CLIENT RULES V1 — explicitly approved by the operator, authoritative over older examples.
Only selected active signals are eligible. Process the three Apify employment signals
first; company/source qualification for those signals is allowed through their approved
routes. Do not spend time on optional extra contacts while discovery/pending work remains.

APIFY: each selected signal uses its own exact catalog expression, France, configured
sort and 25 results. Pages 1..4, FOUR primary attempts TOTAL including the first, not
four retries. Never simplify keywords. Stop new primary discovery after five retained
publications, but finish and publish eligible paid rows even above five. Company cluster
follow-ups are separate from the four calls. A single relevant primary vacancy identifies
a possible employer: qualify its ICP, persist pass, then use the company-scoped helper.
Final cluster evidence requires at least THREE complementary distinct dated IT/data/product
jobs within the configured window. Repost requires 45 days proven still open OR two
verified distinct publications. Internal recruiter requires a real internal tech hire.

ORDER: verify employer identity, ICP, actual signal and dates; check EXACT source URL
AND signal_key duplication; qualify through leadsignal_qualify_candidate; publish through
leadsignal_publish_candidate; THEN perform Perplexity contact discovery and verification.
Never publish before the duplicate result is known. A previous event at the same company,
the same company name, another URL, or the same URL under another signal is NOT a duplicate.
Use the full source_url exactly, including path/query; no semantic event merging, domain-only
comparison, or silent URL normalization. Use a candidate_key derived from signal_key and
the exact primary source URL (for example SHA256 of their JSON array). Cluster keeps one
primary source URL and its supporting dated job URLs; do not rotate primary URLs merely
to republish the same candidate. Supporting links do not independently block publication.
Read historical URLs for an early check before paid follow-ups when the primary URL is known.
The server repeats the URL+signal check immediately before insertion under a transaction lock.

QUALIFICATION RPC: save the candidate as ready_for_validation, with existing company_id,
all source/evidence/date fields, evidence.icp_fit_verified (or the allowed unknown-size
exception), evidence.signal_verified=true, evidence.deduplication_checked=true and concrete
notes. Call leadsignal_qualify_candidate with p_batch_id,p_worker_id,p_lease_token,p_candidate_id.
Only its successful receipt counts as a newly qualified opportunity. A researched/pending
candidate never resets discovery counters. Publishing calls the same check again.

NON-APIFY: one attempt is one NEW discovery request actually dispatched, including an
HTTP error or uncertain network outcome. Re-reading cached results, status/items reads,
company/source verification, contacts and locally refused requests are not attempts.
After TWENTY dispatched discovery requests since the last successful NEW qualification,
stop new discovery for this signal. Each new qualification resets the counter; replaying
the same qualification does not. Finish already collected evidence even at the limit;
a new genuine qualification may reopen discovery. Stop at FIVE retained publications
for each non-Apify signal. Never save dummy candidates to reset the allowance.
research_request.py records dispatch automatically. For approved RSS/direct source
discovery outside that helper: record_attempt start, call leadsignal_dispatch_discovery
with p_batch_id,p_worker_id,p_lease_token,p_attempt_key immediately before the ONE actual
request, then record its real outcome. No dispatch call for cached/local/non-discovery work.
Do not automatically replay uncertain requests. Status errors before dispatch are not sent.

SIZE: make up to two targeted size checks after reusing evidence. Unknown size alone is
not a rejection: keep employee_count=null, document checks and 'Taille inconnue', use
the existing unknown-size exception when every other criterion passes. Unknown employer
identity is different; known out-of-range size and explicit exclusions remain disqualifying.

CONTACTS: publish even with zero contacts, then attempt Perplexity discovery; verify real
people, current role/employer and exact LinkedIn URL before accepting. Maximum FIVE linked
contacts per opportunity, not five required. One useful bounded discovery pass plus needed
profile verification is enough to record searched, even with zero accepted. Preserve pending
people privately. Do not repeatedly enrich already searched opportunities while other work
remains. A genuine provider error may block contacts but never removes the opportunity.
No other contact provider. No contact research for an unpublished or rejected opportunity.

No numeric score or score_basis; legacy minimum_score is not a gate. Priority remains a
separate SQL field. Do not edit old published candidates/opportunities, delete records,
or simulate provider calls against the production ledger. An actual business mistake is
reported for operator review, not repaired by improvising state transitions.
Use the controller timestamps; do useful work until the real deadline or report the real
early-stop reason. Worker expiry is handover, not batch suspension. Only current verified
operational failures can block routes. Never carry historical failures forward as facts.


OPERATOR OVERRIDE runner_4h_v1 (supersedes conflicting older project/skill examples):
Apply the exact current ICP snapshot except the explicit missing-size exception below.
Discovery requests use 20 results. Non-Apify discovery stops after 20 dispatched
requests since the last NEW server-qualified opportunity; pending candidates never reset it. The older 12-call and headcount 3+3
suspension rules are replaced. Change ineffective search angles after three requests,
but never suspend a signal because of session expiry, no result, unknown employee count,
an unreviewed list, or a missing earlier Actor run. Provider/account failures remain blocks.
Only the controller computes no-progress pauses. A worker may save a typed operational
block with reason_code provider_account_limit, provider_configuration, provider_unavailable,
or schema_error and a concrete error plus attempt_id; never use controller_suspension.

SIZE UNKNOWN EXCEPTION:
First reuse reliable entity-scoped evidence. Make at most two targeted company size
checks for a candidate across this batch. If still unknown, continue publication when
identity, France geography, business activity, exclusions, signal, dates and dedup pass.
Set employee_count=null for a NEW company; never overwrite a known count with null.
Record evidence.size_status='unknown', size_unknown_reason=<checks and missing fact>,
known_size_outside_icp=false, other_icp_criteria_verified=true, icp_fit_verified=false.
Include 'Taille inconnue' in one short event_data.reason bullet. Server policy explicitly
accepts this exception only for this upgraded batch. Never invent a midpoint/count.
An established out-of-range employer remains ineligible; unknown does not override it.
This is only an ICP-size exception: headcount-growth still requires proof of growth,
cluster still requires 3 distinct dated jobs at the same employer, and other signal
proofs are unchanged. Company identity unknown is not company size unknown.

PROVIDER EXECUTION (one request per attempt, no manual duplicate logging):
Use /opt/hermes/.venv/bin/python3 /opt/data/leadsignal_runner/research_request.py
with one JSON object on stdin:
batch_id, worker_id, lease_token, attempt_key, signal_key, purpose, provider, action, input.
Never expose the lease or any credential in reports. The helper reads keys itself.
Tavily: provider='tavily', action='search', input={'query':<actual query>}.
Use purpose='discovery' for finding NEW events; 'company_qualification' for identity,
sector and size of a named candidate; 'source_verification' for its date/source proof.
The helper requests 20 results for discovery, 5 for verification, includes actual usage,
and applies the batch dates to discovery. No domain restriction is added. It stores
the exact request and all returned result rows. This approved helper REPLACES native
web_search for Tavily in this batch, solely to enforce input and usage accounting.
Do not call native web_search or terminal HTTP as a parallel Tavily route. Reuse
receipt/cached results after uncertain completion, never repeat a paid call to fix a log.

TED: provider='ted', action='search', signal_key='it_data_rfp', purpose='discovery',
input={'query':'(PC=72000000 OR PC=48000000) AND CY=FRA','page':1}.
The helper sends POST https://api.ted.europa.eu/v3/notices/search without authentication,
with batch dates, 20 notices and an explicit field list. Do not use the public website
as API base. A 400 query error is not a signal-wide block; preserve exact error and
fix the expert query against official fields, no blind retries. BOAMP remains approved;
each actual BOAMP request gets its own start/completion record, not a grouped summary.

Apify: use the existing apimaestro~linkedin-jobs-scraper-api Actor, verified schema,
current APIFY_TOKEN and existing source reservation/cluster contracts. The helper
reserves atomically; do not reserve manually or double-log. It does not enlarge budgets:
provider='apify', action='start', input=<actual validated Actor JSON>, purpose='discovery'.
Save returned run_id/dataset_id immediately; for polling use action='status', run_id,
input={}, purpose='source_verification'; for dataset use action='items', run_id,
dataset_id, input={'offset':0}, purpose='source_verification'. Both must reference a
run recorded in THIS batch. Poll no more often than every 15 seconds. Each status
returns the cumulative run charge; accounting counts it once, never sums snapshots.
Read final status and record it even if zero results. No unseen employee count is
inferred from total_jobs. Review all received rows or checkpoint unreviewed rows.
Use existing cluster_company_followup.md for every distinct ICP-eligible employer
(including allowed unknown size), not only the first company in the discovery lot.
Publish cluster sources as 3..5 distinct vacancy URLs with their publication dates.

AUDIT AND QUALITY:
Persist a decision for each returned row keyed attempt_id/position or dataset_id/job_id:
decision, reason, source URL/date, candidate_id, missing proof. Keep the raw results.
Before publishing, open/verify the EXACT primary source URL: company, event, title and
date must agree with the evidence. A Wimi article is not an Ecritel source. Never use
a different page's RSS date. Only an exact same primary URL AND same signal is a duplicate. Different URLs are not merged by event.
Use short business summary bullets without RPC names, IDs, logs or API details.
Priority: the three selected Apify signals first. Within that phase, reconcile paid uncertain calls and finish actionable
qualified/pending candidates before unrelated new discovery. Use the least-covered-first
list for NEW discovery only. If a pending lead cannot progress, save its missing proof
and continue another eligible task; do not loop on the same exhausted check. Optional
extra contacts never monopolize the worker while other signals are untouched.
Contacts remain Perplexity-only via the existing helper. Reuse saved answers and verify
exact profiles; once an opportunity has accepted linked contacts, optional additional
people do not block completion. Set contact_workflow.state='searched' after the bounded
search even if some people remain pending, and refresh accepted_count/linked_contact_ids
from actual opportunity_contacts reads. Never accept an unverified person to fill a quota.
Use the actual current UTC time and controller worker_deadline; it is a maximum, not
a claim that eleven minutes have elapsed. Continue useful authorized work while time
remains, reserving a short checkpoint margin. If returning early, report the actual
reason (blocked, no actionable work, or other observed condition), never deadline
reached without checking the clock. The controller owns elapsed-time reporting.
Do not launch background workers, subagents or a second controller. No invented costs.

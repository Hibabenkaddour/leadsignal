# Discovery and completion budgets — client rules v1

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

Execution accounting: use research_request.py for Tavily, TED, BOAMP and Apify.
Its receipt files reconcile logging failures without repeating the provider request.
Status and items reads never consume a primary discovery slot. Cluster company
reservations retain their existing separate per-company limits. Never reserve twice.
A provider refusal after dispatch is an attempt; a local validation refusal is not.
The database authorization immediately precedes the HTTP request. If execution dies
between those operations, the reservation is uncertain and conservatively retained;
do not replay it or claim a completed provider call without a receipt.
Report observed costs only, cumulative Apify run usage once, pending costs separately.
Never count records, pages of cached results or pending candidates as publications.

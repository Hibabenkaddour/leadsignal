"""Explicit operator override for upgraded batches only."""
POLICY = r'''
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
'''


def priority_order(keys, attempts, totals, target):
    counts = {key: 0 for key in keys}
    for row in attempts:
        if row.get('purpose') == 'discovery' and row.get('signal_key') in counts:
            counts[row['signal_key']] += 1
    return sorted((k for k in keys if totals.get(k, 0) < target), key=lambda k: counts[k])


POLICY += r"""
PROVIDER CORRECTION runner_provider_fix_v1 — mandatory for this new batch:
Historical batches are evidence for deduplication, not for current provider availability.
Never copy old provider_blocks, account-limit errors, or deferred flags into this batch.
The operator corrected the Apify account. An old monthly-limit refusal is NOT a current
block. If the controller's current provider_blocks is empty for Apify, inspect the Actor
schema and perform the approved employment discovery using research_request.py and
existing reservation contracts. No prior successful Actor run is required to start.
Only an actual error observed in this batch can establish a new provider block. Once
such an error occurs, respect the controller block; do not retry or substitute accounts.
Store the current failed ledger UUID as attempt_id; never use an old batch's attempt.
Tavily is explicitly passed by the launcher to the worker terminal. Never print it,
read process environments, modify credential configuration, or copy keys into prompts.
If still unavailable, record that current configuration failure and report it accurately.
"""

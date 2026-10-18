"""Offline policy and deterministic controller helpers. No network on import."""
import datetime as dt

JOB_RULES = {'cluster_min_jobs': 3, 'cluster_window_days': 60,
             'open_min_days': 60, 'repost_min_publications': 2}

def structured_deferrals(workers, keys):
    # Typed real operational blocks only. Coverage/no-progress belongs to controller.
    result = {}
    permitted = {'provider_account_limit','provider_quota','provider_configuration',
                 'provider_unavailable','schema_error'}
    for row in sorted(workers, key=lambda r: r.get('attempt_number', 0)):
        cp = row.get('checkpoint') or {}
        entries = cp.get('discovery_status') or {}
        if not isinstance(entries, dict): continue
        for key, item in entries.items():
            if key not in keys or not isinstance(item, dict): continue
            if (item.get('deferred_for_batch') is True and item.get('reason_code') in permitted
                and item.get('attempt_id') and str(item.get('reason') or '').strip()):
                result[key] = {'worker_id':row['id'], 'reason':str(item['reason'])[:1000],
                               'reason_code':item['reason_code'], 'attempt_id':item['attempt_id'],
                               'source':'structured_checkpoint'}
    return result


def no_progress_deferrals(attempts, candidates, keys, threshold=20):
    """A finite discovery allowance, not a claim that sources are exhausted.
    Unknown/interrupted outcomes don't count as successful empty research.
    Only newly recorded candidates reset this counter; contacts don't.
    """
    result = {}
    for key in keys:
        last_candidate = max((r.get('created_at') or '' for r in candidates
                              if r.get('signal_key') == key), default='')
        rows = [r for r in attempts if r.get('signal_key') == key
                and r.get('purpose') == 'discovery' and r.get('state') == 'succeeded'
                and (r.get('result_summary') or {}).get('counts_as_discovery') is not False
                and not (r.get('result_summary') or {}).get('no_provider_call')
                and (r.get('result_summary') or {}).get('outcome') != 'not_performed'
                and (r.get('started_at') or '') > last_candidate]
        if len(rows) >= threshold:
            result[key] = {'source': 'controller_no_progress_allowance',
                'reason': f'{len(rows)} completed discovery attempts without a new saved candidate; discovery paused for this batch, existing candidate/contact work remains allowed.',
                'attempt_ids': [r['id'] for r in rows]}
    return result

RELIABILITY_INSTRUCTIONS = '''
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

DISCOVERY SUSPENSION: use the typed operational contract in runner_4h_v1.
The server enforces 20 dispatched non-Apify discoveries since the last new qualification receipt; a pending candidate never resets it.

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
Use Perplexity for contact discovery AND exact-profile verification. No other provider
may perform contact work. If unavailable, preserve pending contacts and record blocked.
Do not keep probing a blocked provider.
Check the helper with --check when needed: it reads configuration only, no provider call.
Generated answers and returned URLs are leads, NOT automatically accepted contacts.
Verify identity, current company/role and direct profile evidence under contact_policy.
Use candidate_id on all attempts and the logging timestamp for actual verification.
Never expose keys or put them in arguments or JSON inputs. Never modify installed helpers.
'''

RELIABILITY_INSTRUCTIONS += "\nCONTACTS PERPLEXITY ONLY â€” operator decision, supersedes all earlier contact routes:\nUse ONLY the installed perplexity_contacts.py helper for discovery of people,\nverification of their professional role/company, and exact LinkedIn profile URLs.\nNo Tavily/web_search, Google/RSS, Apify, web_extract or terminal HTTP fallback for\nCONTACT research or profile verification. These providers retain their existing\nbusiness-event discovery/qualification routes. Do not relabel a people search as\ncompany_qualification or source_verification to evade the restriction.\nIf Perplexity is unavailable, preserve verified contacts and pending evidence,\nrecord contact_workflow.state='blocked' and the exact reason; no substitute provider.\nContact count is still not a publication gate. Perplexity text alone is not proof:\ninspect the returned citations and indexed snippets, match the exact person/profile\nand current company. Use purpose=linkedin_verification for acceptance evidence.\nverification_attempt_id must be the successful Perplexity attempt for THIS candidate\nand batch; verification_source_url must be in its returned sources. Preserve its\nfinished_at as verified_at. If evidence conflicts about a title, ask Perplexity to\nresolve the specific conflict using dated/official sources. If unresolved, keep the\nperson pending; never publish a guessed title or overwrite an existing verified contact.\nDo not spend the contact helper on company sector/size qualification.\n\nQUALIFICATION CONSISTENCY:\nCheck exclusions (including scale-ups), actual business activity and actual employer\nbefore contacts/publication. NAF/APE alone is insufficient evidence of present business\nactivity. A staffing advertiser's client vacancies do not prove growth of its own team.\nRecord exact sources and entity scope; unresolved eligibility is pending, not invented.\nDo not revise existing opportunities or delete orphan companies automatically.\nFor RFPs, retain the current ICP interpretation; if the buyer fails ICP record the\ncandidate-specific mismatch. Do not claim all BOAMP/TED buyers or every RFP is ineligible.\n\nLONG-OPEN OFFER EXCEPTION (tech_role_repost only):\nKeep the genuine original source_published_at. Never replace it with scrape date/today.\nFor an old original source, publication requires evidence.long_open_proof with:\njob_id, employer_company_id, original_published_at (YYYY-MM-DD), source_url (same as\nevent_data.source_url), original_publication_verified=true, currently_open_verified=true,\nsame_vacancy_verified=true, verification_attempt_id, verification_excerpt.\nThe verification attempt must be a successful source_verification for THIS candidate,\nbatch and job URL, finished during this batch. result_summary.job_observation must\nrecord matching job_id, employer_company_id, original_published_at, source_url,\noriginal_publication_verified=true, currently_open_verified=true, same_vacancy_verified=true,\nand a nonempty excerpt from the actual observed source. Observation must prove still open.\nAt least 60 days must separate original publication from the verification date.\nevent_date may be null or the original publication date; never invent a new event date.\nOnly use this exception after SQL migration has been installed. Other signal freshness\nchecks stay unchanged. Record job_evidence.py output as a consistency check, not final\npublication approval. The server checks the supporting attempt; generic eligible=true\nalone is insufficient. Company qualification and deduplication still apply.\n\nREPORTING: Always report published signals / ALL snapshot-selected signals, including\nsuspended ones in the denominator. A suspended signal is not achieved or removed.\nUse controller timestamps, not a guessed wall-clock report time. Report contact work\nremaining/blocked separately; fewer than three contacts is not automatically pending.\n"

RELIABILITY_INSTRUCTIONS += "\nEMPLOYMENT DATA REVIEW — 2026-10-07\nUse cached datasets and prior checkpoint evidence before requesting new collection.\nFor each dataset, count actual items and distinct job_id values, then group by company_urn\n(or canonical company URL; missing identity stays unresolved). total_jobs is a search-level\nfield, never a company vacancy count or employee count. Advertiser grouping is preliminary:\nconfirm the actual hiring employer before counting jobs toward any signal.\nA dispersed search sample cannot establish absence of a three-job cluster at an employer.\nPrioritize eligible employers with two distinct roles for a targeted follow-up, using only\nparameters verified in the installed Actor schema and existing source/budget permissions.\nDo not automatically increase maxItems, paginate, repeat a broad query, or launch another\nActor just because the target is unmet. Preserve current call allowances and stop rules.\nCompany URLs and company_urn identify advertisers; a staffing client's job must never be\nattributed to the advertiser's own team. Distinct job IDs alone do not establish distinct\nvacancies: reconcile location copies and confirm complementary roles and publication dates.\n\nESN is not by itself an exclusion. Apply the explicit ICP exclusions, size, geography,\nactivity and actual employer evidence. Distinguish an ESN employing its own consultants\nfrom a recruitment agency advertising for an unidentified client. Do not invent a blanket\n'hors ESN' rule or automatically approve every ESN. The same distinction applies to an\ninternal recruiter hired by an ESN. Any explicit ICP exclusion continues to take precedence.\n\nEvaluate date semantics per vacancy. Neither created_at nor posted_at automatically proves\noriginal publication; differences do not establish reposting. One inconsistent vacancy must\nnot invalidate an entire dataset. Preserve uncertain evidence with the exact missing proof.\nKeep existing cluster/long-open/repost thresholds and server validation unchanged.\n\nPersist an audit in the existing worker checkpoint under employment_offer_audit, without\ncreating tables: key each reviewed entry by dataset_id + ':' + job_id. Record signal_key,\nadvertiser, actual_employer (or null), decision (candidate/rejected/needs_verification),\nreason, evidence URLs, candidate_id if present, and missing_proof. Candidate means a lead,\nnot publication approval. Use the existing lease-checked checkpoint writer, merge earlier\nentries rather than overwrite them, and read back the update. Preserve full source files.\nReport received, unique, reviewed, unreviewed and decision counts per dataset; do not claim\nall items were processed if some were omitted. If persistence fails, report that failure.\nBefore deferring discovery, save credible unfinished leads using the existing candidate\nprotocol and the specific next action. Never fabricate a candidate just to reset a budget.\nAn unmet target or unreviewed rows do not authorize exceeding budgets or clearing a suspension.\nExisting fresh business evidence may inform another selected signal, but revalidate that\nsignal's criteria and normal/mini-test duplicate rules; never auto-publish across signals.\nCONTACTS remain Perplexity-only; no Tavily or Apify contact research or profile verification.\n"


def continuation_view(workers):
    """Session expiry is a handover, never a batch-wide discovery block.
    Preserve typed operational blockers and the separate no-progress allowance.
    """
    import copy
    rows = copy.deepcopy(sorted(workers, key=lambda w: w.get('attempt_number', 0)))
    for row in rows:
        cp = row.get('checkpoint')
        if not isinstance(cp, dict):
            continue
        entries = cp.get('discovery_status', {})
        if isinstance(entries, dict):
            for item in entries.values():
                if isinstance(item, dict) and item.get('reason_code') == 'worker_session_end':
                    item['deferred_for_batch'] = False
        for field in ('headcount_discovery', 'executive_recruiting_pain_discovery'):
            item = cp.get(field)
            if isinstance(item, dict) and item.get('reason_code') == 'worker_session_end':
                item['deferred_for_batch'] = False
    return rows


def resumable_candidate(row, assignments):
    if row.get('state') == 'ready_for_validation': return True
    if assignments.get(row['id'], 0) >= 2: return False
    workflow = (row.get('evidence') or {}).get('research_workflow') or {}
    if workflow.get('state') != 'blocked': return True
    return (workflow.get('reason_code') in ('worker_session_end', 'verification_pending')
            and bool(str(workflow.get('next_action') or '').strip()))

RELIABILITY_INSTRUCTIONS += "\nWORKER HANDOVER CONTRACT V2:\nThe controller supplies separate UTC worker_deadline, research_deadline and final_deadline.\nNever infer batch exhaustion from your session allowance or a guessed clock.\nAt session end, preserve unfinished candidate evidence with research_workflow containing\nstate='pending', reason_code='worker_session_end', next_action=<specific remaining step>.\nFor incomplete verification use state='pending', reason_code='verification_pending', next_action.\nUse blocked for actual permission, provider, schema or evidence-access blockers; do not\nassert a SQL migration is absent merely because you have not checked it. If schema status\nis unknown record the exact read-only check needed; never run DDL as a research worker.\nA signal paused solely because this session ends must carry discovery_status[SIGNAL_KEY]\nwith deferred_for_batch=false, reason_code='worker_session_end', reason=<remaining work>.\nOther suspensions keep their genuine operational reason; do not relabel a quota/budget\nor evidence blocker to get another session. The controller continues a signal after session-end handovers until the research\ndeadline or a genuine route/no-progress block. Each unfinished research candidate\nremains limited to two assignments.\nDo not reset these allowances by recreating candidates. Preserve normal provider blocks,\n20-call no-progress limit, freshness rules, Perplexity-only contacts and publication gates.\n"

from upgrade_policy import POLICY
RELIABILITY_INSTRUCTIONS += "\n" + POLICY

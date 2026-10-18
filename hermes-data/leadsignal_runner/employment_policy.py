"""Fixed employment discovery contracts and safe BOAMP query construction."""
import json
import urllib.parse
from pathlib import Path

SIGNALS = ('tech_job_velocity_cluster', 'tech_role_repost', 'internal_tech_recruiter_hiring')
CATALOG = json.loads(Path(__file__).with_name('apify_primary_queries.json').read_text(encoding='utf-8'))
BOAMP_URL = 'https://www.boamp.fr/api/explore/v2.1/catalog/datasets/boamp/records'

def primary_input(signal, supplied):
    if signal not in SIGNALS:
        raise ValueError('Unsupported employment signal')
    page = supplied.get('page_number', 1)
    if type(page) is not int or not 1 <= page <= 4:
        raise ValueError('Four primary calls maximum: pages 1..4')
    expected = dict(CATALOG[signal], page_number=page)
    # A page-only input asks the helper to build the exact approved request.
    if set(supplied) != {'page_number'} and supplied != expected:
        raise ValueError('Use the complete approved query unchanged, or page_number only')
    return expected

def company_input(signal, supplied):
    if signal != 'tech_job_velocity_cluster':
        raise ValueError('Company follow-up is reserved for cluster')
    company = supplied.get('company_id')
    page = supplied.get('page_number', 1)
    if not isinstance(company, str) or not company.isdigit() or type(page) is not int or not 1 <= page <= 3:
        raise ValueError('One verified company ID and page 1..3 required')
    expected = dict(company_id=company, keywords='', location='France', sort='recent', page_number=page, limit=10)
    if 'date_posted' in supplied:
        if supplied['date_posted'] != 'month':
            raise ValueError('Only the month filter is approved')
        expected['date_posted'] = 'month'
    if supplied != expected:
        raise ValueError('Company follow-up input does not match approved template')
    return expected

def boamp_url(supplied, first, last):
    if set(supplied) - {'terms', 'page'}:
        raise ValueError('BOAMP accepts terms and page, never a raw where expression')
    terms = supplied.get('terms', ['informatique', 'logiciel', 'cloud', 'data', 'cyber'])
    page = supplied.get('page', 1)
    if type(page) is not int or not 1 <= page <= 25:
        raise ValueError('BOAMP page must be 1..25')
    if not isinstance(terms, list) or not 1 <= len(terms) <= 12:
        raise ValueError('BOAMP requires 1..12 terms')
    for term in terms:
        if not isinstance(term, str) or not 1 <= len(term.strip()) <= 80 or any(not (c.isalnum() or c in ' -') for c in term):
            raise ValueError('BOAMP terms accept letters, numbers, spaces and hyphens only')
    words = ' OR '.join('search(objet, ' + json.dumps(t.strip(), ensure_ascii=False) + ')' for t in terms)
    where = f'dateparution >= date\'{first}\' AND dateparution <= date\'{last}\' AND ({words})'
    return BOAMP_URL + '?' + urllib.parse.urlencode(dict(where=where, limit=20, offset=(page-1)*20, order_by='dateparution DESC'))


# PENDING_EMPLOYMENT_QUALIFICATION_V1
def pending_qualification_work(lots, decisions, calls):
    jobs = {}
    for lot in lots:
        for job in lot.get('raw_results') or []:
            jid = str(job.get('job_id') or '')
            if jid.isascii() and jid.isdigit():
                jobs[(lot['id'], jid)] = job
    groups = {}
    for d in decisions:
        key = str(d.get('canonical_job_key') or '')
        jid = key[3:] if key.startswith('li:') else key
        job = jobs.get((d.get('source_lot_id'), jid))
        if job is None or d.get('signal_key') not in SIGNALS:
            continue
        if (d.get('publication_status') in ('published', 'duplicate')
                or d.get('icp_decision') == 'reject' or d.get('signal_decision') == 'reject'):
            continue
        if d.get('icp_decision') == 'pending':
            kind = 'qualify_employer_icp'
        elif d.get('icp_decision') == 'pass' and d.get('signal_decision') in ('pending', 'not_evaluated'):
            if d['signal_key'] == 'tech_job_velocity_cluster':
                continue  # Existing company-followup scheduler handles ICP-pass cluster.
            kind = 'verify_employment_signal'
        else:
            continue
        company = str(job.get('company_urn') or '')
        identity = company if company.isascii() and company.isdigit() else str(d.get('company_key') or '')
        if not identity:
            identity = str(d.get('source_lot_id')) + ':' + key
        group = groups.setdefault((kind, d['signal_key'], identity), {
            'kind': kind, 'signal_key': d['signal_key'],
            'company_name': job.get('company'),
            'linkedin_company_id': company if company.isascii() and company.isdigit() else None,
            'decision_refs': []})
        ref = {'source_lot_id': d['source_lot_id'], 'canonical_job_key': key,
               'signal_key': d['signal_key']}
        if ref not in group['decision_refs']:
            group['decision_refs'].append(ref)
    return list(groups.values())

def employment_state(api, batch, all_rows):
    lots = all_rows(api, 'leadsignal_apify_lots', batch_id='eq.'+batch)
    decisions = []
    while True:
        page = api.get('leadsignal_apify_decisions', batch_id='eq.'+batch,
            order='signal_key,canonical_job_key', limit='500', offset=str(len(decisions)))
        decisions.extend(page)
        if len(page)<500: break
    calls = all_rows(api, 'leadsignal_cluster_company_calls', batch_id='eq.'+batch)
    counts = {k: sum(l['signal_key']==k for l in lots) for k in SIGNALS}
    work = []
    for lot in lots:
        if lot['state'] in ('reserved', 'running', 'unknown'):
            work.append({'kind':'reconcile_call', 'signal_key':lot['signal_key'], 'lot_id':lot['id'], 'state':lot['state']})
        for job in lot.get('raw_results') or []:
            jid = str(job.get('job_id') or '')
            rows = [d for d in decisions if d['source_lot_id']==lot['id'] and d['signal_key']==lot['signal_key'] and jid.isascii() and jid.isdigit() and d['canonical_job_key'] in (jid, 'li:' + jid)]
            if not rows:
                work.append({'kind':'review_raw', 'signal_key':lot['signal_key'], 'lot_id':lot['id'], 'job_id':jid})
                continue
            d = rows[0]
            if (d.get('publication_status') in ('published', 'duplicate')
                    or d.get('icp_decision') == 'reject' or d.get('signal_decision') == 'reject'):
                continue
            if d['publication_status']=='ready':
                work.append({'kind':'publish_ready', 'signal_key':d['signal_key'], 'candidate_id':d.get('candidate_id')})
            if d['signal_key']=='tech_job_velocity_cluster' and d['icp_decision']=='pass':
                company = str(job.get('company_urn') or '')
                if not (company.isascii() and company.isdigit()):
                    work.append({'kind':'resolve_cluster_employer_id', 'signal_key':d['signal_key'],
                        'lot_id':lot['id'], 'job_id':jid, 'company_name':job.get('company')})
                    continue
                related = [c for c in calls if c['linkedin_company_id']==company]
                if company.isdigit() and not related:
                    work.append({'kind':'cluster_company_followup', 'signal_key':d['signal_key'], 'company_id':company})
    for call in calls:
        if call['state'] in ('reserved','running','unknown') or (call['state']=='succeeded' and call.get('qualification_report') is None):
            work.append({'kind':'finish_company_followup', 'signal_key':'tech_job_velocity_cluster', 'call_id':call['id']})
    work.extend(pending_qualification_work(lots, decisions, calls))
    return counts, list({json.dumps(w,sort_keys=True):w for w in work}.values())

INSTRUCTIONS = '''
EMPLOYMENT POLICY V2 — overrides older conflicting employment budgets and inputs.
For each selected employment signal perform its OWN primary search. A cluster run
does not replace the repost primary search, even when keywords are the same.
Use research_request.py only. Apify action=start with input={"page_number":1..4}
builds the full fixed keyword catalog, France, 25 results and configured sort.
Do not call the reservation RPC yourself: the helper reserves atomically before send.
Exactly FOUR primary attempts maximum per signal per batch, including the first.
Failed/uncertain sends consume a slot. No unlogged retries, alternate keywords,
alternate Actor, direct HTTP, or native Apify route. Never use a single keyword.
Stop new primary calls once five opportunities are published, but fully review and
publish all qualifying results already paid for, even when total exceeds five.
Review every raw row and persist leadsignal_apify_decisions before advancing pages.
Unresolved evidence stays pending with an explicit reason; do not fabricate proof.
PRIMARY CLUSTER RESULTS ARE EMPLOYER DISCOVERY, NOT THE COMPLETE VACANCY INVENTORY.
One relevant vacancy is sufficient to retain a potential employer for ICP qualification.
Never reject cluster eligibility merely because the primary page has fewer than three
vacancies for that employer. Keep signal_decision=pending until the company-scoped
verification is completed. A missing date is pending proof, not automatic rejection.
The three distinct dated jobs threshold applies to FINAL publication evidence.
Definitive ICP or signal rejection ends that signal's work; it does not reject other
signals automatically. Do not rewrite historical decisions during a new batch.
resolve_cluster_employer_id means verify the numeric LinkedIn employer identifier
before using the company-follow-up helper; never guess it.
For EVERY distinct ICP-pass cluster employer perform a separate company follow-up
using the approved company_id template (keywords empty, France, recent, limit 10,
date_posted=month, page 1). This is separate from the four-primary-call budget.
Existing company reservations, three pages per scope and month/full-window order
remain enforced. Reuse paid company results across workers. Save qualification_report.
When new Apify runs are blocked, recorded status/dataset reads remain allowed;
do not restart the Actor. Reconcile uncertain reservations before any new call.
Cluster requires AT LEAST THREE complementary distinct dated IT/data/product jobs.
Publish one opportunity/company and persist 3..5 dated links in cluster_job_sources.
Repost: original publication + fresh still-open proof after 60 days, OR two distinct
verified publications of the same vacancy/employer. posted_at/created_at differences
alone are not proof. Preserve job_evidence.py and server evidence requirements.
Internal recruiter: actual internal tech recruitment vacancy + ICP + dedup.
Contacts remain Perplexity-only and are not a publication prerequisite.
BOAMP: research_request.py provider=boamp, action=search, purpose=discovery,
signal_key=it_data_rfp, input={"terms":["informatique","logiciel","cloud","data","cyber"],"page":1}.
The helper fixes endpoint, date window, escaping and pagination; do not construct
raw ODSQL/where expressions or use the homepage. Each HTTP request has its own log.
Do not reject all public tenders globally; apply the current buyer ICP individually.
'''

INSTRUCTIONS += "\nPENDING EMPLOYMENT QUALIFICATION V1:\nAn offer reviewed with icp_decision=pending is NOT completed work.\nqualify_employer_icp means verify employer identity, entity scope, sector, location,\nsize and exclusions against the batch ICP using the approved qualification routes.\nNo company-scoped Apify follow-up is authorized while ICP is pending.\nReuse paid evidence for the same verified company ID across all lots and signals;\ndifferent jobs, locations or identical dates alone do not prove a qualifying cluster.\nPersist the supported ICP decision with evidence on the listed decision_refs;\nreuse it across that employer's pending rows only after verifying identical scope.\nIf still unresolved, record precise missing evidence and the next action; do not\nmark pass just to clear the queue and do not repeat the same exhausted check.\nOnce cluster ICP passes, use the existing company follow-up helper and reservations,\nseparate from the four-primary-attempt budget. Recompute employment_state after\npersisting the qualification so the next step can proceed within this session.\nverify_employment_signal means finish date/repost or internal-recruiter evidence\nusing approved routes, then persist the reasoned result; do not repeat raw review.\nWork on resumable paid leads before unrelated new discovery. A worker session end\nis a handover, not proof of exhaustion or an instruction to defer the entire batch.\n"

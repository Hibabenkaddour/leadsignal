"""Read-only work selection for client rules v2. No provider requests."""
import hashlib
import json
import datetime as dt
from urllib.parse import urlparse

def unique_contacts(contacts):
    found = {}
    for c in contacts:
        url = str(c.get('linkedin_url') or '').strip().rstrip('/').lower()
        if (c.get('linkedin_url_verified') is True and c.get('contact_status') == 'valid'
            and url.startswith('https://www.linkedin.com/in/') and c.get('full_name') and c.get('title')):
            found.setdefault(url, c)
    return list(found.values())

def contact_action(candidate, linked, attempts, review=False):
    linked = unique_contacts(linked)
    nomination = candidate['signal_key'] == 'leader_tech_data_nomination'
    workflow = (candidate.get('evidence') or {}).get('contact_workflow') or {}
    discovery = [a for a in attempts if a.get('purpose') == 'contact_discovery']
    if any(a.get('state') in ('started','unknown','interrupted') for a in attempts):
        return None  # Reconcile uncertainty before any paid retry.
    if nomination and not workflow.get('nominees_verified'):
        if len(discovery)>=2 or sum(a.get('purpose')=='linkedin_verification' for a in attempts)>=5:
            return None
        if workflow.get('state')=='searched' and any(a.get('purpose')=='linkedin_verification' and a.get('state')=='succeeded' for a in attempts):
            return None
        return 'verify_named_nominees'
    if len(linked) >= 5: return None
    if len(linked) >= 2: return None
    if not discovery: return 'reuse_then_complete_to_two'
    if review and not linked and len(discovery) < 2:
        return 'zero_contact_catchup'
    return None

def contact_backlog(api, batch, review=False):
    from client_rules import retained, rows
    result = []
    for c in retained(api, batch):
        linked = rows(api,'opportunity_contacts',opportunity_id='eq.'+c['opportunity_id'])
        attempts = rows(api,'leadsignal_research_attempts',batch_id='eq.'+batch,
            candidate_id='eq.'+c['id'],provider='eq.perplexity')
        action = contact_action(c, linked, attempts, review)
        if action:
            result.append(dict(candidate_id=c['id'],opportunity_id=c['opportunity_id'],
                signal_key=c['signal_key'],linked_count=len(unique_contacts(linked)),action=action,
                instruction='Call leadsignal_reuse_company_contacts_v2 first; then re-read links.'))
    return result

def cross_signal_work(lots, decisions, calls, keys):
    if 'tech_role_repost' not in keys: return []
    result=[]
    for lot in lots:
        if lot.get('signal_key') != 'tech_job_velocity_cluster': continue
        for job in lot.get('raw_results') or []:
            jid=str(job.get('job_id') or '')
            if not jid.isascii() or not jid.isdigit(): continue
            done=any(d.get('source_lot_id')==lot['id'] and d.get('signal_key')=='tech_role_repost'
                     and str(d.get('canonical_job_key','')).removeprefix('li:')==jid for d in decisions)
            if not done:
                result.append(dict(kind='review_cluster_for_repost',signal_key='tech_role_repost',
                    source_lot_id=lot['id'],job_id=jid,origin_signal='tech_job_velocity_cluster'))
    # Follow-up data is retained by run/dataset; track separate reviews in checkpoints.
    for call in calls:
        if call.get('state')=='succeeded':
            result.append(dict(kind='review_followup_for_repost',signal_key='tech_role_repost',
                call_id=call['id'],instruction='Read existing dataset via approved helper; no new start.'))
    return result

def review_work(api,batch,keys,workers):
    from client_rules import rows
    done=set()
    for worker in workers:
        for key in (worker.get('checkpoint') or {}).get('review_v2_completed',[]):
            if isinstance(key,str): done.add(key)
    tasks=[]
    for table,kind in [('leadsignal_apify_lots','review_paid_lot'),
                       ('leadsignal_candidates','review_candidate')]:
        for row in rows(api,table,batch_id='eq.'+batch):
            if row.get('signal_key') not in keys: continue
            if table=='leadsignal_candidates' and row.get('state')=='published': continue
            key=kind+':'+row['id']
            if key not in done: tasks.append(dict(review_key=key,kind=kind,id=row['id'],signal_key=row['signal_key']))
    # Every selected signal gets a ledger review, even if no candidate was saved.
    for key in keys:
        identity='review_discovery:'+key
        if identity not in done:tasks.append(dict(review_key=identity,kind='review_discovery_ledger',signal_key=key))
    return tasks

def unresolved_cross_work(work,workers):
    done=set()
    for worker in workers:
        done.update((worker.get('checkpoint') or {}).get('repost_cross_completed',[]))
    result=[]
    for task in work:
        identity='repost_followup:'+str(task.get('call_id'))
        if task.get('kind')!='review_followup_for_repost' or identity not in done:
            task=dict(task)
            if task.get('kind')=='review_followup_for_repost':task['review_key']=identity
            result.append(task)
    return result

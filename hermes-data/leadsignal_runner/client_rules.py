"""Client rules v1. Pure selection logic plus read-only API aggregation."""
EMPLOYMENT = ('tech_job_velocity_cluster','tech_role_repost','internal_tech_recruiter_hiring')
VALID = ('new','review','qualified')
VERSION = 'client_rules_v2'
POLICY = "CLIENT RULES V2 — authoritative replacement of conflicting V1 rules.\nKeep the selected ICP, active signals, exclusions, no-score publication, unknown-size\nexception, four fixed Apify primary searches and non-Apify maximum five unchanged.\nTwenty actually dispatched discoveries without a NEW server qualification still stop\nnon-Apify discovery. Keep catalog keywords and request inputs unchanged.\n\nCONTACTS: after publication call leadsignal_reuse_company_contacts_v2 with the four\nbatch/worker/lease/candidate UUIDs BEFORE any Perplexity request. It reuses recent verified\nsame-company contacts without fabricating receipts. Inspect other company contacts in\nSupabase too: old/unverified profiles are leads to verify, not accepted reusable contacts.\nRe-read unique valid links. At zero or one, perform a bounded Perplexity completion pass;\nat TWO or more stop general search. Maximum five linked; zero never blocks publication.\nFor leader_tech_data_nomination extract named appointees and their new roles from the\narticle. Verify their exact LinkedIn and association, even with two unrelated contacts.\nSave nomination evidence and contact_workflow.nominees_verified only once the actual\nnamed people have verified linked profiles. Do not fill all five slots with unrelated\npeople first. One bounded nomination pass, not endless repetitions. Existing matching\nrecent evidence can satisfy this without paying again.\nIf five unrelated people are already linked, still verify named nominees and retain\ntheir verified evidence privately; report that the link cap needs operator arbitration.\nDo not delete existing links automatically or exceed five to force a nominated person in.\nNew people use perplexity_contacts.py only, never another provider. Save full_name,\ncompany_id,title,relevance_reason,priority,source_type,linkedin_url,linkedin_url_verified,\ncompany_association_verified,verification_method,verification_source_url,verification_notes,\nverified_at and verification_attempt_id in candidate.contact_research. Accepted profiles\nrequire a completed linkedin_verification attempt for this batch/candidate, actual\nfinished_at, cited exact profile and current employer/role. Pending people remain private.\nCall leadsignal_enrich_candidate_contacts after saving and read back actual links.\nNever directly insert a new unverified person. Reuse RPC is the distinct server route\nfor pre-existing evidence; it does not forge a new Perplexity attempt.\n\nREPOST: >=60 days proven continuously/still open, OR two verified distinct publications.\nCheck own primary results AND already-paid cluster primary/follow-up offers when repost\nis selected. No new start to re-read data. Original lot/job provenance remains; create a\nseparate repost decision. A cluster rejection is not a repost rejection. Persist outcomes\nfor cross reviews in checkpoint.repost_cross_completed (review_key strings), with reasons\nand proof links; write completion only after actual review. The original vacancy date\ncan precede the freshness window: the current open observation must be fresh.\n\nDEDUPE: same real employer, signal and business event/information is duplicate even\nacross different URLs. Compare article content, actors, dates and material facts, not\njust titles or company names. Distinct events at one company remain eligible; same URL\nis not independent proof of sameness if its content changed. Never rotate URLs to evade.\nRead ALL historical signals for same company/signal using pagination and inspect relevant\ncontents and linked opportunities; resolve aliases/legal identity before creating company.\nBefore qualify/publish save evidence.deduplication_v2 with verdict='distinct_event',\nevent_key (stable description of event identity, no URL), facts (structured actors/date/\nobject), compared_signal_ids (all compared historical signal UUID strings), rationale\n(concrete differences, minimum 20 characters). Reuse an existing event_key for same event;\ndo not invent a fresh key to publish twice. For jobs compare actual vacancies and period;\nfor appointments person and role; acquisitions buyer/target; funding round/date; product\nand launch; subsidiary and parent. Semantic uncertainty requires evidence, not blind rejection.\nSQL enforces history coverage and shared event identities; it does NOT independently\nunderstand content. Final semantic judgment remains evidence-based reviewer work.\nUse same existing qualify and publish RPCs, identity/ICP/proof first, dedupe before publish.\n\nEND REVIEW: when primary discoveries are capped/suspended/at target, review ALL existing\nselected-signal results, incomplete candidates and rejections once with concrete reasons.\nNo reopening spent budgets, bypassing failures, or publishing above non-Apify caps.\nComplete checkpoint.review_v2_completed with review_key only after reviewing that object,\nand record decision, missing proof and next action separately. Partial work stays pending.\nFor zero-contact batch opportunities retry one useful targeted Perplexity discovery after\ndatabase reuse (maximum two contact_discovery dispatches per candidate in this batch).\nNever replay a request with an uncertain outcome. Respect provider blocks and deadlines.\n\nWORKER TIME: a session is ONE SLICE, not the entire discovery-to-publication pipeline.\nDo the next useful bounded step now, persist immediately and hand over exact IDs/proofs/\nnext action. Lack of time for the whole pipeline is NOT a reason to do no discovery.\nDo not start an HTTP call whose maximum timeout cannot fit remaining time; save instead.\nA 11-minute deadline is not a batch suspension and does not reset research counters.\nNever alter past published history automatically; report actual errors for operator review.\n"

def rows(api, table, **query):
    result=[]
    while True:
        page=api.get(table,**query,order='id',limit='500',offset=str(len(result)))
        result.extend(page)
        if len(page)<500: return result

def retained(api,batch):
    candidates=rows(api,'leadsignal_candidates',batch_id='eq.'+batch,state='eq.published',
                    select='id,signal_key,opportunity_id,evidence')
    found={}
    ids=list(dict.fromkeys(c['opportunity_id'] for c in candidates if c.get('opportunity_id')))
    for start in range(0,len(ids),100):
        for o in rows(api,'opportunities',id='in.('+','.join(ids[start:start+100])+')',select='id,status'):
            if o['status'] in VALID: found[o['id']]=o
    return [c for c in candidates if c.get('opportunity_id') in found]

def counts(api,batch,keys,target=5):
    result={k:0 for k in keys}; seen=set()
    for c in retained(api,batch):
        if c['signal_key'] in result and c['opportunity_id'] not in seen:
            result[c['signal_key']]+=1;seen.add(c['opportunity_id'])
    if any(v>target for k,v in result.items() if k not in EMPLOYMENT):
        raise RuntimeError('Retained publication cap violation')
    return result

def contact_backlog(api,batch,review=False):
    from v2_workflows import contact_backlog as implementation
    return implementation(api,batch,review)

def collect_discovery_deferrals(api,batch,keys,workers=None):
    from research_reliability_addon import structured_deferrals
    workers=workers if workers is not None else rows(api,'leadsignal_workers',batch_id='eq.'+batch)
    failed=rows(api,'leadsignal_research_attempts',batch_id='eq.'+batch,state='eq.failed',
                select='id,signal_key,error_message')
    evidence={r['id']:r for r in failed if r.get('error_message')}
    verified=[]
    for w in workers:
        cp=dict(w.get('checkpoint') or {}); entries=cp.get('discovery_status') or {}
        if not isinstance(entries,dict): entries={}
        cp['discovery_status']={k:v for k,v in entries.items() if isinstance(v,dict)
          and v.get('attempt_id') in evidence and evidence[v['attempt_id']].get('signal_key')==k}
        verified.append(dict(w,checkpoint=cp))
    result=structured_deferrals(verified,keys)
    for k in keys:
        if k in EMPLOYMENT: continue
        status=api.rpc('leadsignal_discovery_budget',p_batch_id=batch,p_signal_key=k)
        if status['attempts_since_qualification']>=20:
            result[k]={'source':'client_discovery_budget','reason':'20 dispatched discoveries without a new qualification; finish paid candidates, not new discovery',
                       'attempts':status['attempts_since_qualification']}
    return result

def apify_phase(keys,totals,primary_counts,blocks,deferred,target=5):
    return [k for k in EMPLOYMENT if k in keys and totals.get(k,0)<target
            and primary_counts.get(k,0)<4 and 'apify' not in blocks
            and k not in deferred]

def prioritize(keys,attempts,totals,target):
    counts={k:0 for k in keys}
    for a in attempts:
        if a.get('purpose')=='discovery' and a.get('signal_key') in counts: counts[a['signal_key']]+=1
    return sorted((k for k in keys if totals.get(k,0)<target),key=lambda k:(k not in EMPLOYMENT,counts[k],k))

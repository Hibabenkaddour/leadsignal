#!/usr/bin/env python3
"""Offline vacancy evidence checks and durable observations; no provider calls.
All verification flags are reviewer attestations, never independent proof.
"""
import argparse
from contextlib import closing
import datetime as dt
import json
from pathlib import Path
import sqlite3
import sys
from urllib.parse import urlparse
import uuid

STORE = Path('/opt/data/leadsignal_runner/runtime/job_observations.sqlite3')

def date(value):
    return dt.date.fromisoformat(value)

def verified_job(job, company, today):
    required = ('job_id','title','source_url','employer_company_id','observed_at')
    if any(not isinstance(job.get(k),str) or not job[k].strip() for k in required):
        raise ValueError('Missing job identity, title, source, employer or observation time')
    if job['employer_company_id'] != company or job.get('actual_employer_verified') is not True:
        raise ValueError('Actual employer must be verified; agency/platform advertiser is insufficient')
    if urlparse(job['source_url']).scheme != 'https' or not urlparse(job['source_url']).hostname:
        raise ValueError('HTTPS evidence URL required')
    observed=dt.datetime.fromisoformat(job['observed_at'].replace('Z','+00:00'))
    if observed.tzinfo is None or observed.date()>today:
        raise ValueError('Observation requires timezone and cannot be in the future')
    return observed.date()

def evaluate(data, today=None):
    today=today or dt.datetime.now(dt.timezone.utc).date()
    company=str(uuid.UUID(data['company_id']))
    window=data['max_source_age_days']
    if type(window) is not int or window<1: raise ValueError('Positive ICP freshness window required')
    jobs=data['jobs']; key=data['signal_key']
    if not isinstance(jobs,list): raise ValueError('jobs must be an array')
    for job in jobs: verified_job(job,company,today)
    eligible=[]
    if key=='tech_job_velocity_cluster':
        seen=set()
        for job in jobs:
            if job.get('publication_date_verified') is not True or job.get('tech_role_verified') is not True:
                continue
            if job.get('publication_date_semantics')!='original_publication': continue
            published=date(job['published_at'])
            identity=job['job_id']
            if identity not in seen and 0 <= (today-published).days <= min(60,window):
                eligible.append(identity);seen.add(identity)
        passed=len(eligible)>=3 and data.get('distinct_complementary_roles_verified') is True
        reason='At least three distinct complementary jobs with verified original dates and actual employer required'
    elif key=='tech_role_repost':
        for job in jobs:
            observed=verified_job(job,company,today)
            if job.get('currently_open_verified') is not True or not 0 <= (today-observed).days <= window: continue
            long_open=False
            if job.get('publication_date_verified') is True and job.get('publication_date_semantics')=='original_publication':
                published=date(job['published_at'])
                long_open=(observed-published).days>=60 and job.get('same_vacancy_verified') is True
            publications=set()
            for item in job.get('publication_events',[]):
                if item.get('distinct_publication_verified') is True and item.get('same_role_employer_verified') is True and urlparse(item.get('source_url','')).scheme=='https':
                    when=date(item['published_at'])
                    if when<=today: publications.add(when)
            repost=len(publications)>=2 and 0 <= (today-max(publications)).days <= window
            if long_open or repost: eligible.append(job['job_id'])
        passed=bool(eligible);reason='Requires verified 60-day open vacancy or two distinct publications of the same role/employer'
    else: raise ValueError('Unsupported employment signal')
    return {'eligible':passed,'signal_key':key,'qualifying_job_ids':eligible,'reason':reason,
            'independent_source_verification':False,'other_icp_and_freshness_rules_still_apply':True}

def record(data, store=STORE):
    company=str(uuid.UUID(data['company_id'])); now=dt.datetime.now(dt.timezone.utc).date()
    job=data['job'];verified_job(job,company,now)
    # No history rewriting: identical observations are idempotent, conflicts rejected.
    with closing(sqlite3.connect(store)) as db:
        db.execute('CREATE TABLE IF NOT EXISTS observations (company TEXT, job TEXT, observed TEXT, evidence TEXT, PRIMARY KEY(company,job,observed))')
        identity=(company,job['job_id'],job['observed_at'])
        payload=json.dumps(job,sort_keys=True,ensure_ascii=False)
        old=db.execute('SELECT evidence FROM observations WHERE company=? AND job=? AND observed=?',identity).fetchone()
        if old and old[0]!=payload: raise ValueError('Conflicting observation; historical evidence preserved')
        db.execute('INSERT OR IGNORE INTO observations VALUES (?,?,?,?)',identity+(payload,))
        db.commit()
    return {'saved':True,'company_id':company,'job_id':job['job_id'],'observation_is_not_publication':True}

def history(company, store=STORE):
    company=str(uuid.UUID(company))
    if not store.exists(): return []
    with closing(sqlite3.connect('file:'+str(store)+'?mode=ro',uri=True)) as db:
        return [json.loads(r[0]) for r in db.execute('SELECT evidence FROM observations WHERE company=? ORDER BY observed DESC LIMIT 500',(company,))]

def main():
    p=argparse.ArgumentParser();g=p.add_mutually_exclusive_group()
    g.add_argument('--record-observation',action='store_true');g.add_argument('--history',metavar='COMPANY_UUID')
    g.add_argument('--schema',action='store_true')
    a=p.parse_args()
    if a.schema:
        print(json.dumps({'evaluation_fields': ['company_id (UUID)', 'signal_key (tech_job_velocity_cluster or tech_role_repost)', 'max_source_age_days (positive integer)', 'jobs (array)', 'distinct_complementary_roles_verified (boolean, cluster only)'],
            'job_fields': ['job_id (stable same-vacancy identifier, not a location copy)', 'title', 'source_url (HTTPS)', 'employer_company_id (UUID)', 'observed_at (ISO timestamp with timezone)', 'actual_employer_verified (boolean)', 'tech_role_verified (boolean)', 'published_at (YYYY-MM-DD original publication)', 'publication_date_verified (boolean)', 'publication_date_semantics (original_publication or unknown)', 'currently_open_verified (boolean)', 'same_vacancy_verified (boolean)', 'publication_events (array, optional)'],
            'publication_event_fields': ['published_at (YYYY-MM-DD)', 'source_url (HTTPS)', 'distinct_publication_verified (boolean)', 'same_role_employer_verified (boolean)'],
            'record_observation_fields': ['company_id', 'job'], 'warning': 'Verification booleans must reflect actual evidence; missing facts are not true.'}))
        return
    result=history(a.history) if a.history else record(json.load(sys.stdin)) if a.record_observation else evaluate(json.load(sys.stdin))
    print(json.dumps(result,ensure_ascii=False))
if __name__=='__main__':
    try: main()
    except Exception as exc:
        print(json.dumps({'eligible':False,'error':str(exc)}));sys.exit(2)

"""One recorded request, one response receipt. No implicit retry of paid calls."""
import datetime as dt
import json
import os
import sys
import urllib.request
import urllib.error
import urllib.parse
import hashlib
from employment_policy import primary_input, company_input, boamp_url
from pathlib import Path

TED_URL = 'https://api.ted.europa.eu/v3/notices/search'
ACTOR = 'apimaestro~linkedin-jobs-scraper-api'


class RequestFailure(Exception):
    pass


def http(method, url, data=None, token=None):
    headers = {'Content-Type': 'application/json', 'User-Agent': 'LeadSignal-research/4h'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(url, data=None if data is None else json.dumps(data).encode(),
                                 headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=50) as res:
            return json.load(res)
    except urllib.error.HTTPError as exc:
        message = f'HTTP {exc.code}'
        try:
            body = json.loads(exc.read())
            error = body.get('error') or body.get('detail') or {}
            message += ': ' + (str(error.get('type', '')) + ' ' + str(error.get('message', ''))
                              if isinstance(error, dict) else str(error))
        except Exception:
            pass
        # No headers, query-string credentials or unfiltered HTML in exceptions.
        for name in ('APIFY_TOKEN', 'TAVILY_API_KEY', 'SUPABASE_SERVICE_ROLE_KEY'):
            secret = os.environ.get(name)
            if secret:
                message = message.replace(secret, '[REDACTED]')
        raise RequestFailure(message[:700]) from None
    except (urllib.error.URLError, TimeoutError, ValueError):
        raise RequestFailure('Transport/response error; outcome uncertain, do not repeat automatically') from None


def prepare(spec, batch):
    provider, action = spec['provider'], spec.get('action', 'search')
    supplied = spec.get('input') or {}
    if not isinstance(supplied, dict):
        raise ValueError('input must be an object')
    if any('token' in k.lower() or 'api_key' in k.lower() for k in supplied):
        raise ValueError('Never put credentials in input')
    purpose = spec['purpose']
    if purpose not in ('discovery', 'source_verification', 'company_qualification'):
        raise ValueError('Contact work must use perplexity_contacts.py')
    now = dt.datetime.now(dt.timezone.utc)
    if now >= dt.datetime.fromisoformat(batch['research_deadline'].replace('Z', '+00:00')):
        raise ValueError('Research deadline reached')
    started = dt.datetime.fromisoformat(batch['started_at'].replace('Z', '+00:00'))
    age = int(batch['icp_snapshot']['max_source_age_days'])
    first, last = (started - dt.timedelta(days=age)).date().isoformat(), started.date().isoformat()
    if provider == 'tavily':
        if action != 'search' or set(supplied) - {'query'}:
            raise ValueError('Tavily input: query only; dates and result count supplied by controller')
        query = supplied.get('query')
        if not isinstance(query, str) or not query.strip():
            raise ValueError('A real query is required')
        payload = dict(query=query, topic='general', search_depth='basic',
                       max_results=20 if purpose == 'discovery' else 5,
                       include_usage=True, include_answer=False, include_raw_content=False,
                       auto_parameters=False, include_published_date=True)
        # Old supporting identity evidence remains usable for qualification.
        if purpose == 'discovery':
            payload.update(start_date=first, end_date=last, filter_by_published_date=True)
        return 'POST', 'https://api.tavily.com/search', payload, 'TAVILY_API_KEY'
    if provider == 'boamp':
        if action != 'search': raise ValueError('BOAMP action must be search')
        return 'GET', boamp_url(supplied, first, last), None, None
    if provider == 'ted':
        if action != 'search' or set(supplied) - {'query', 'page'}:
            raise ValueError('TED input accepts query and page only')
        page = supplied.get('page', 1)
        if type(page) is not int or not 1 <= page <= 10:
            raise ValueError('TED page must be 1..10; no automatic pagination')
        query = supplied.get('query') or '(PC=72000000 OR PC=48000000) AND CY=FRA'
        payload = {'query': f'({query}) AND PD>={first.replace("-", "")} AND PD<={last.replace("-", "")}',
                   'fields': ['publication-number', 'publication-date', 'notice-title', 'buyer-name'],
                   'page': page, 'limit': 20, 'scope': 'ALL', 'paginationMode': 'PAGE_NUMBER'}
        return 'POST', TED_URL, payload, None
    if provider == 'apify':
        if action == 'start':
            # Schema validation, ICP/grouping and any SQL reservations still apply.
            if spec.get('actor', ACTOR) != ACTOR:
                raise ValueError('Only the existing LinkedIn jobs Actor is allowed')
            supplied = company_input(spec['signal_key'], supplied) if 'company_id' in supplied else primary_input(spec['signal_key'], supplied)
            return 'POST', f'https://api.apify.com/v2/acts/{ACTOR}/runs?maxItems={supplied["limit"]}', supplied, 'APIFY_TOKEN'
        run = spec.get('run_id', '')
        if not run.isalnum():
            raise ValueError('run_id required')
        if action == 'status':
            return 'GET', f'https://api.apify.com/v2/actor-runs/{run}', None, 'APIFY_TOKEN'
        if action == 'items':
            dataset = spec.get('dataset_id', '')
            if not dataset.isalnum():
                raise ValueError('dataset_id required')
            offset = supplied.get('offset', 0)
            if type(offset) is not int or offset < 0 or set(supplied) - {'offset'}:
                raise ValueError('items input accepts a nonnegative offset only')
            return 'GET', f'https://api.apify.com/v2/datasets/{dataset}/items?clean=true&limit=100&offset={offset}', None, 'APIFY_TOKEN'
    raise ValueError('Unsupported provider/action')


def summarize(spec, request, response):
    provider = spec['provider']
    summary = {'provider': provider, 'tool': 'research_request.py', 'request_input': request,
               'request_count': 1, 'counts_as_discovery': spec['purpose'] == 'discovery'}
    if provider == 'tavily':
        if not isinstance(response, dict) or not isinstance(response.get('results'), list) or response.get('error'):
            raise RequestFailure('Invalid Tavily response')
        summary.update(result_count=len(response['results']), results=response['results'],
                       usage=response.get('usage'), request_id=response.get('request_id'))
    elif provider == 'boamp':
        if not isinstance(response, dict) or not isinstance(response.get('results'), list):
            raise RequestFailure('Invalid BOAMP JSON response: results array required')
        summary.update(result_count=len(response['results']), results=response['results'], total_count=response.get('total_count'))
    elif provider == 'ted':
        if not isinstance(response, dict) or not isinstance(response.get('notices'), list):
            raise RequestFailure('Invalid TED response: expected notices array')
        if response.get('timedOut'):
            raise RequestFailure('TED timedOut=true; partial response, not a completed search')
        summary.update(result_count=len(response['notices']), results=response['notices'],
                       total_notice_count=response.get('totalNoticeCount'))
    elif provider == 'apify' and spec.get('action') == 'items':
        if not isinstance(response, list):
            raise RequestFailure('Invalid Apify dataset response')
        summary.update(result_count=len(response), results=response, counts_as_discovery=False,
                       run_id=spec['run_id'], dataset_id=spec['dataset_id'])
    else:
        data = response.get('data') or {}
        if not data.get('id') or not data.get('status'):
            raise RequestFailure('Invalid Apify run response')
        summary.update(run_id=data['id'], dataset_id=data.get('defaultDatasetId'),
                       run_status=data['status'], usageTotalUsd=data.get('usageTotalUsd'),
                       chargedEventCounts=data.get('chargedEventCounts'), usage=data.get('usage'),
                       counts_as_discovery=spec.get('action') == 'start',
                       result_count=None)
    return summary


def main():
    from test_runner import API
    spec = json.load(sys.stdin)
    api = API()
    batch_id, worker, lease, key = (spec[k] for k in ('batch_id', 'worker_id', 'lease_token', 'attempt_key'))
    import uuid, fcntl
    uuid.UUID(batch_id)
    uuid.UUID(worker)
    directory = Path(os.environ.get('LEADSIGNAL_LOG_DIR', '/opt/data/leadsignal_test_logs')) / batch_id / 'worker-data'
    receipt_name = hashlib.sha256(key.encode()).hexdigest()
    directory.mkdir(parents=True, exist_ok=True)
    lock = (directory / ('request-' + receipt_name + '.lock')).open('a')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    api.rpc('leadsignal_assert_worker', p_batch_id=batch_id, p_worker_id=worker, p_lease_token=lease)
    batch = api.get('leadsignal_batches', id='eq.' + batch_id)[0]
    if batch.get('execution_config', {}).get('controller') != 'leadsignal_runner_4h_v1':
        raise ValueError('This helper is limited to upgraded batches')
    if spec['provider'] in ('ted', 'boamp') and spec['signal_key'] != 'it_data_rfp':
        raise ValueError('TED is reserved for it_data_rfp')
    if spec['provider'] == 'apify' and spec['signal_key'] not in ('tech_job_velocity_cluster', 'tech_role_repost', 'internal_tech_recruiter_hiring'):
        raise ValueError('Apify is reserved for employment signals')
    method, url, payload, env = prepare(spec, batch)
    token = os.environ.get(env) if env else None
    if env and not token:
        raise ValueError(f'{env} absent; no provider request sent')
    # Stable request fingerprint rejects reuse of a completed key for a different query.
    fingerprint = hashlib.sha256(json.dumps([method, url, payload], sort_keys=True).encode()).hexdigest()
    previous = api.get('leadsignal_research_attempts', batch_id='eq.' + batch_id, attempt_key='eq.' + key)
    if previous:
        old = previous[0]
        if old['state'] == 'succeeded' and (old.get('result_summary') or {}).get('request_fingerprint') == fingerprint:
            print(json.dumps({'cached': True, 'result': old['result_summary']}))
            return
        raise ValueError('Attempt exists; reconcile it, no automatic provider replay')
    if spec['provider'] == 'apify' and spec.get('action') in ('status', 'items'):
        from test_runner import all_rows
        rows = all_rows(api, 'leadsignal_research_attempts', batch_id='eq.' + batch_id, provider='eq.apify')
        matched = [r.get('result_summary') or {} for r in rows
                   if (r.get('result_summary') or {}).get('run_id') == spec['run_id']]
        if not matched or (spec['action'] == 'items' and not any(s.get('dataset_id') == spec['dataset_id'] for s in matched)):
            raise ValueError('Run/dataset is not recorded in this batch')
    if spec['provider']=='apify' and spec.get('action')=='items' and not any(x.get('run_status')=='SUCCEEDED' for x in matched):
        raise ValueError('Record a successful final run status before fetching items')
    from test_runner import provider_blocks
    if spec['provider'] in provider_blocks(api, batch_id) and not (spec['provider']=='apify' and spec.get('action') in ('status','items')):
        raise ValueError('Provider blocked in this batch; no request sent')
    reservation = None
    if spec['provider'] == 'apify' and spec.get('action') == 'start':
        if 'company_id' in payload:
            table = 'leadsignal_cluster_company_calls'
            reservation = api.rpc('leadsignal_reserve_cluster_company_call', p_batch_id=batch_id,
                p_worker_id=worker, p_lease_token=lease, p_input=payload)
        else:
            table = 'leadsignal_apify_lots'
            reservation = api.rpc('leadsignal_reserve_apify_lot', p_batch_id=batch_id,
                p_worker_id=worker, p_lease_token=lease, p_signal_key=spec['signal_key'], p_input=payload)
        if isinstance(reservation, list): reservation = reservation[0]
    details = {'signal_key': spec['signal_key'], 'provider': spec['provider'], 'purpose': spec['purpose'],
               'query_text': json.dumps(payload if payload is not None else {'url': url}, ensure_ascii=False),
               'candidate_id': spec.get('candidate_id')}
    api.rpc('leadsignal_record_attempt', p_batch_id=batch_id, p_lease_token=lease,
            p_attempt_key=key, p_action='start', p_details=details)
    receipt = directory / ('receipt-' + receipt_name + '.json')
    # Authorization immediately precedes dispatch. An uncertain authorization never sends.
    if spec['purpose'] == 'discovery' and spec['provider'] != 'apify':
        try:
            api.rpc('leadsignal_dispatch_discovery', p_batch_id=batch_id, p_worker_id=worker,
                    p_lease_token=lease, p_attempt_key=key)
        except Exception:
            # Best-effort closure, without any provider call or automatic replay.
            try:
                api.rpc('leadsignal_record_attempt', p_batch_id=batch_id, p_lease_token=lease,
                    p_attempt_key=key, p_action='failed', p_details={
                    'error_message':'Discovery authorization failed; no provider request sent',
                    'result_summary':{'no_provider_call':True,'request_fingerprint':fingerprint}})
            except Exception:
                pass
            raise
    try:
        response = http(method, url, payload, token)
        summary = summarize(spec, payload if payload is not None else {'url': url}, response)
        summary['request_fingerprint'] = fingerprint
        if reservation:
            summary.update(reservation_id=reservation['id'], reservation_table=table,
                           counts_as_discovery=table == 'leadsignal_apify_lots')
    except RequestFailure as exc:
        if reservation:
            api.patch(table, reservation['id'], {'state':'unknown' if 'uncertain' in str(exc) else 'failed', 'error_message':str(exc)})
        api.rpc('leadsignal_record_attempt', p_batch_id=batch_id, p_lease_token=lease,
                p_attempt_key=key, p_action='failed', p_details={'error_message': str(exc),
                'result_summary': {'provider': spec['provider'], 'request_input': payload,
                                   'request_fingerprint': fingerprint, 'outcome_uncertain': 'uncertain' in str(exc)}})
        raise
    # Save the provider response before DB completion; a DB failure never repeats the paid request.
    temporary = receipt.with_suffix('.tmp')
    temporary.write_text(json.dumps({'attempt_key': key, 'summary': summary}), encoding='utf-8')
    os.replace(temporary, receipt)
    if reservation:
        api.patch(table, reservation['id'], {'state':'running', 'run_id':summary['run_id'], 'dataset_id':summary.get('dataset_id')})
    if spec['provider'] == 'apify' and spec.get('action') in ('status','items'):
        for table_name in ('leadsignal_apify_lots','leadsignal_cluster_company_calls'):
            for row in api.get(table_name, batch_id='eq.'+batch_id, run_id='eq.'+spec['run_id']):
                if spec['action']=='items':
                    if payload is not None or (spec.get('input') or {}).get('offset',0)!=0:
                        raise ValueError('Bounded Actor result uses one dataset page; reconcile manually')
                    limit = int(row['request_input']['limit'])
                    if len(response)>limit:
                        raise ValueError('Actor returned more than contracted limit; receipt saved, no truncation')
                    api.patch(table_name,row['id'], {'raw_results':response,'state':'succeeded','finished_at':dt.datetime.now(dt.timezone.utc).isoformat()})
                elif summary.get('run_status') in ('FAILED','ABORTED','TIMED-OUT'):
                    api.patch(table_name,row['id'], {'state':'failed','error_message':'Apify '+summary['run_status']})
    api.rpc('leadsignal_record_attempt', p_batch_id=batch_id, p_lease_token=lease,
            p_attempt_key=key, p_action='succeeded', p_details={'result_summary': summary,
            'cost_usd': None, 'cost_is_estimate': False})
    print(json.dumps({'cached': False, 'result': summary}, ensure_ascii=False))


def check_providers():
    """Read-only account lookup + one public TED search; no Actor/Tavily/model call."""
    missing = [k for k in ('TAVILY_API_KEY', 'APIFY_TOKEN') if not os.environ.get(k)]
    if missing:
        raise ValueError('Missing provider environment variable(s): ' + ', '.join(missing))
    account = http('GET', 'https://api.apify.com/v2/users/me', token=os.environ['APIFY_TOKEN'])['data']
    limits = http('GET', 'https://api.apify.com/v2/users/me/limits', token=os.environ['APIFY_TOKEN'])['data']
    print(json.dumps({'apify_account': {'id': account.get('id'), 'username': account.get('username')},
                      'monthly_limit_usd': limits.get('limits', {}).get('maxMonthlyUsageUsd'),
                      'monthly_used_usd': limits.get('current', {}).get('monthlyUsageUsd')}))
    response = http('POST', TED_URL, {'query': 'CY=FRA AND PC=72000000',
        'fields': ['publication-number', 'publication-date', 'notice-title', 'buyer-name'],
        'page': 1, 'limit': 1, 'scope': 'ALL', 'paginationMode': 'PAGE_NUMBER'})
    summarize({'provider': 'ted', 'purpose': 'discovery'}, {}, response)
    print('TED v3: valid notices response. Tavily key present, authentication not tested. No Actor started.')


if __name__ == '__main__':
    try:
        if sys.argv[1:] == ['--check-providers']:
            check_providers()
        else:
            main()
    except (ValueError, KeyError, RequestFailure, RuntimeError, OSError) as exc:
        print(json.dumps({'error': str(exc), 'retry_provider': False}))
        sys.exit(1)

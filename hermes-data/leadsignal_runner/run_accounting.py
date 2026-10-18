"""Batch accounting: only provider-reported quantities, never guessed prices."""
import json
from pathlib import Path
from decimal import Decimal


def number(value):
    if isinstance(value, (int, float)) and not isinstance(value, bool) and value >= 0:
        return value
    return None


def aggregate(attempts, folder, workers):
    result = {'deepseek': {'tokens': None, 'workers_measured': 0, 'workers_expected': len(workers),
                           'complete': False, 'models': [], 'auxiliary_coverage': 'unknown'},
              'perplexity': {'tokens': None, 'reported_usd': None, 'responses_measured': 0},
              'tavily': {'credits': None, 'calls_measured': 0, 'calls_missing_usage': 0},
              'apify': {'reported_usd': None, 'runs_measured': 0, 'runs_missing_usage': 0,
                        'charged_events': {}, 'unit': 'USD and provider event counts; no universal credit unit'},
              'unresolved_attempt_ids': [], 'accounting_complete': False}
    files = list(Path(folder).glob('worker-*-usage.json')) + list((Path(folder) / 'worker-data').glob('worker-*-usage.json'))
    seen_workers = set()
    deep_tokens = 0
    auxiliary = True
    for path in sorted(files):
        if path.name in seen_workers:
            continue
        try:
            usage = json.loads(path.read_text(encoding='utf-8'))
        except (OSError, ValueError):
            continue
        if not isinstance(usage, dict):
            continue
        model = str(usage.get('model') or '')
        provider = str(usage.get('provider') or '')
        if 'deepseek' not in (model + provider).lower():
            continue  # Never label a different/unknown model as DeepSeek.
        totals = usage.get('total_including_auxiliary')
        total = number(totals.get('total_tokens')) if isinstance(totals, dict) else None
        if total is None:
            auxiliary = False
            total = number(usage.get('total_tokens'))
        if total is None:
            i, o = number(usage.get('input_tokens')), number(usage.get('output_tokens'))
            if i is not None and o is not None:
                total = i + o
        if total is None:
            continue
        seen_workers.add(path.name)
        deep_tokens += total
        result['deepseek']['models'].append(model or provider)
    d = result['deepseek']
    d['workers_measured'] = len(seen_workers)
    d['tokens'] = deep_tokens if seen_workers else None
    d['models'] = sorted(set(d['models']))
    d['complete'] = len(seen_workers) == len(workers) and bool(workers) and auxiliary
    d['auxiliary_coverage'] = 'included' if seen_workers and auxiliary else 'not established'
    costs, tokens, response_ids = [], [], set()
    credits = []
    runs = {}
    expected_apify_without_id = 0
    for row in attempts:
        s = row.get('result_summary') or {}
        provider = s.get('provider') or row.get('provider')
        if row.get('state') == 'started':
            result['unresolved_attempt_ids'].append(row['id'])
        if s.get('no_provider_call') or s.get('outcome') == 'not_performed':
            continue
        if provider == 'perplexity':
            key = s.get('response_id') or row['id']
            if key in response_ids:
                continue
            response_ids.add(key)
            usage = s.get('usage') or {}
            token = number(usage.get('total_tokens'))
            cost = number((usage.get('cost') or {}).get('total_cost'))
            if token is not None:
                tokens.append(token)
            if cost is not None:
                costs.append(Decimal(str(cost)))
        if provider == 'tavily':
            value = number((s.get('usage') or {}).get('credits'))
            if value is not None:
                credits.append(value)
            else:
                result['tavily']['calls_missing_usage'] += 1
        if provider == 'apify' and s.get('run_id'):
            # One cumulative receipt per run, not the sum of each polling snapshot.
            rid = s['run_id']
            prior = runs.get(rid, {})
            if number(s.get('usageTotalUsd')) is not None or not prior:
                runs[rid] = s
        elif provider == 'apify' and row.get('state') in ('started', 'succeeded'):
            expected_apify_without_id += 1
    p = result['perplexity']
    p.update(tokens=sum(tokens) if tokens else None,
             reported_usd=float(sum(costs)) if costs else None,
             responses_measured=len(tokens), responses_expected=len(response_ids),
             complete=len(tokens) == len(response_ids) == len(costs))
    result['tavily'].update(credits=sum(credits) if credits else None, calls_measured=len(credits))
    apify_costs = []
    for rid, s in runs.items():
        value = number(s.get('usageTotalUsd'))
        final = s.get('run_status') in ('SUCCEEDED', 'FAILED', 'ABORTED', 'TIMED-OUT')
        if value is not None:
            apify_costs.append(Decimal(str(value)))
            result['apify']['runs_measured'] += 1
        if value is None or not final:
            result['apify']['runs_missing_usage'] += 1
        result['apify']['charged_events'][rid] = s.get('chargedEventCounts') or {}
    result['apify']['reported_usd'] = float(sum(apify_costs)) if apify_costs else None
    result['apify']['runs_missing_usage'] += expected_apify_without_id
    result['accounting_complete'] = (d['complete'] and p['complete']
        and not result['tavily']['calls_missing_usage']
        and not result['apify']['runs_missing_usage'] and not result['unresolved_attempt_ids'])
    return result


def refresh_apify_receipts(attempts):
    """Fetch final cumulative usage for batch-owned run IDs, at most once per run."""
    from research_request import http
    import os
    token = os.environ.get('APIFY_TOKEN')
    ids = {s['run_id'] for r in attempts for s in [r.get('result_summary') or {}]
           if s.get('provider') == 'apify' and isinstance(s.get('run_id'), str) and s['run_id'].isalnum()}
    receipts = []
    for rid in sorted(ids):
        if not token:
            break
        try:
            data = http('GET', 'https://api.apify.com/v2/actor-runs/' + rid, token=token)['data']
        except Exception:
            continue
        receipts.append({'id': 'accounting:' + rid, 'state': 'succeeded', 'provider': 'apify',
                         'result_summary': {'provider': 'apify', 'run_id': rid,
                            'run_status': data.get('status'), 'usageTotalUsd': data.get('usageTotalUsd'),
                            'chargedEventCounts': data.get('chargedEventCounts')}})
    return receipts


def french_lines(accounting):
    def show(value):
        return 'non disponible' if value is None else str(value)
    d, p, t, a = (accounting[k] for k in ('deepseek', 'perplexity', 'tavily', 'apify'))
    return [
        'Consommations déclarées (détails et couverture : report.json > usage_accounting) :',
        f"- DeepSeek : {show(d['tokens'])} tokens ; {d['workers_measured']}/{d['workers_expected']} workers mesurés ; complet={d['complete']}.",
        f"- Perplexity : {show(p['tokens'])} tokens ; {show(p['reported_usd'])} USD déclarés.",
        f"- Tavily : {show(t['credits'])} crédits ; {t['calls_missing_usage']} appels sans mesure.",
        f"- Apify : {show(a['reported_usd'])} USD déclarés ; {a['runs_missing_usage']} runs sans coût final.",
        'Un total partiel ne représente pas la consommation totale. Aucun prix estimé ajouté.'
    ]

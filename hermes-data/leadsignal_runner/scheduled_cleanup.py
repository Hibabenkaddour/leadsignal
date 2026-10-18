"""Call the restricted, transactional retention RPC. Never retry an uncertain POST."""
import json
import os
import sys
import urllib.error
import urllib.request

def call(dry):
    base = os.environ.get('SUPABASE_URL', '').rstrip('/')
    key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '')
    if not base.startswith('https://') or not key:
        raise SystemExit('Configuration Supabase serveur absente ; aucune suppression.')
    req = urllib.request.Request(base + '/rest/v1/rpc/leadsignal_cleanup_opportunities_11m',
        data=json.dumps({'p_dry_run': dry}).encode(), method='POST',
        headers={'apikey': key, 'Authorization': 'Bearer ' + key,
                 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=75) as response:
            result = json.load(response)
    except urllib.error.HTTPError as exc:
        raise SystemExit(f'Nettoyage refusé : HTTP {exc.code}. Aucun nouvel essai automatique.')
    except (urllib.error.URLError, TimeoutError):
        raise SystemExit('Réponse réseau incertaine ; aucun nouvel essai automatique.')
    print(json.dumps(result, ensure_ascii=False), flush=True)
    return result

if __name__ == '__main__':
    if sys.argv[1:] not in (['--check'], ['--run']):
        raise SystemExit('Usage: scheduled_cleanup.py --check|--run')
    check = call(True)
    if check.get('version') != 'retention_11m_v1':
        raise SystemExit('Version de rétention incompatible.')
    if sys.argv[1:] == ['--run']:
        for _ in range(20):
            result = call(False)
            if result.get('skipped') or result.get('deleted', 0) < 500:
                break

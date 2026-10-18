"""Read Hermes cron status; publish only selected monitoring fields."""
import json, subprocess, sys
COMPOSE="/docker/leadsignal/compose.yaml"
READ = '\nimport json\nfrom datetime import datetime, timezone\nfrom cron.jobs import list_jobs, get_ticker_heartbeat_age\nfrom hermes_time import get_timezone_name\njobs = {j["id"]: j for j in list_jobs(include_disabled=True)}\nage = get_ticker_heartbeat_age()\nrows = []\nfor key, jid in (("research","e60f0426fe41"),("cleanup","5b510e209e2c")):\n    j = jobs.get(jid)\n    d = {\n        "scheduler": "hermes", "installed": j is not None,\n        "heartbeat_age_seconds": age, "timezone": get_timezone_name(),\n    }\n    if j:\n        e = j.get("latest_execution") or {}\n        schedule = j.get("schedule") or {}\n        d.update({\n            "enabled": j.get("enabled") is True,\n            "job_state": j.get("state"),\n            "calendar": schedule.get("expr") if isinstance(schedule,dict) else None,\n            "next_run_at": j.get("next_run_at"),\n            "last_started_at": e.get("started_at") or j.get("last_run_at"),\n            "last_finished_at": e.get("finished_at") or e.get("completed_at"),\n            "execution_state": e.get("state") or e.get("status"),\n            "last_status": j.get("last_status"),\n        })\n    rows.append({"task_key": key, "observed_at": datetime.now(timezone.utc).isoformat(), "payload": d})\nprint(json.dumps(rows))\n'
PUSH = "import json,os,sys,urllib.request,urllib.error\nurl=os.environ.get('SUPABASE_URL','').rstrip('/')\nkey=os.environ.get('SUPABASE_SERVICE_ROLE_KEY','')\nif not url.startswith('https://') or not key: raise SystemExit('Configuration Supabase absente')\npayload=json.load(sys.stdin)\nreq=urllib.request.Request(url+'/rest/v1/leadsignal_scheduler_status?on_conflict=task_key',\n data=json.dumps(payload).encode(),method='POST',headers={'apikey':key,'Authorization':'Bearer '+key,\n 'Content-Type':'application/json','Prefer':'resolution=merge-duplicates,return=minimal'})\ntry:\n with urllib.request.urlopen(req,timeout=20) as r: print('MONITORING_SYNCHRONISE',r.status)\nexcept urllib.error.HTTPError as e: raise SystemExit('Synchronisation refusee HTTP '+str(e.code))\nexcept (urllib.error.URLError,TimeoutError): raise SystemExit('Synchronisation reseau indisponible')\n"

def main():
    result = subprocess.run(["docker","compose","-f",COMPOSE,"exec","-T",
        "--user","hermes","hermes","/opt/hermes/.venv/bin/python3","-c",READ],
        capture_output=True,text=True,timeout=45)
    if result.returncode:
        raise SystemExit("Lecture Hermes impossible; aucune synchronisation.")
    rows=json.loads(result.stdout)
    if not isinstance(rows,list) or len(rows)!=2:
        raise SystemExit("Format Hermes inattendu.")
    if "--check" in sys.argv:
        print(json.dumps(rows,ensure_ascii=False,indent=2))
        return
    result=subprocess.run(["docker","compose","-f",COMPOSE,"exec","-T","hermes",
        "/opt/hermes/.venv/bin/python3","-c",PUSH],
        input=json.dumps(rows),capture_output=True,text=True,timeout=45)
    if result.returncode:
        raise SystemExit("Synchronisation Supabase impossible.")
    print("MONITORING_HERMES_SYNCHRONISE : 2 taches")
if __name__=="__main__":
    main()

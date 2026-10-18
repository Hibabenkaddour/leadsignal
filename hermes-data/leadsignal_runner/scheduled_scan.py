"""Run the existing controller unchanged, or stop that exact scheduled process."""
import fcntl
import json
import os
import signal
import sys
from datetime import datetime, timezone
from pathlib import Path

BASE = Path('/opt/data/leadsignal_test_logs')
PID = BASE / 'scheduled-scan.json'
RUNNER = '/opt/data/leadsignal_runner/test_runner.py'

def identity(pid):
    # Linux start ticks, independent of wall-clock changes.
    return Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()[19]

if sys.argv[1:] == ['stop']:
    if PID.exists():
        record = json.loads(PID.read_text())
        pid = int(record['pid'])
        try:
            args = Path(f'/proc/{pid}/cmdline').read_bytes().split(b'\0')
            if identity(pid) == record['start_ticks'] and RUNNER.encode() in args:
                os.kill(pid, signal.SIGTERM)
                print('Arrêt propre demandé au contrôleur planifié.')
        except ProcessLookupError:
            pass
        except FileNotFoundError:
            pass
    sys.exit(0)

if sys.argv[1:] != ['run']:
    raise SystemExit('Usage: scheduled_scan.py run|stop')
os.umask(0o077)
BASE.mkdir(parents=True, exist_ok=True)
lock = os.open(BASE / 'scheduled-scan.lock', os.O_RDWR | os.O_CREAT, 0o600)
try:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    raise SystemExit('Un lancement planifié est déjà actif.')
os.set_inheritable(lock, True)
log = BASE / ('nightly-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '.log')
fd = os.open(log, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
os.dup2(fd, 1)
os.dup2(fd, 2)
os.close(fd)
(BASE / 'latest-validation-log.txt').write_text(str(log) + '\n')
PID.write_text(json.dumps({'pid': os.getpid(), 'start_ticks': identity(os.getpid())}))
os.execv(sys.executable, [sys.executable, '-u', RUNNER,
    '--workdir', '/opt/data/leadsignal_runner/previous-version/project',
    '--duration-minutes', '300', '--target-per-signal', '5'])

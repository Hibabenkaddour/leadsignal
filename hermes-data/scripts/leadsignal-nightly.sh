#!/bin/bash
set -eu
exec /opt/hermes/.venv/bin/python3 /opt/data/leadsignal_runner/scheduled_scan.py run

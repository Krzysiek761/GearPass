#!/usr/bin/env python3
"""Emit one CPU/RAM sample to local Syslog without external dependencies."""
import json
from pathlib import Path
import socket
import syslog
import time


def cpu():
    values = [int(value) for value in Path("/proc/stat").read_text().splitlines()[0].split()[1:9]]
    return sum(values), values[3] + values[4]


total_before, idle_before = cpu()
time.sleep(0.5)
total_after, idle_after = cpu()
elapsed = total_after - total_before
memory = {
    key: int(value.split()[0])
    for key, value in (line.split(":", 1) for line in Path("/proc/meminfo").read_text().splitlines())
}
sample = {
    "event": "host_metrics",
    "host": socket.gethostname(),
    "cpu_percent": round(100 * (1 - (idle_after - idle_before) / elapsed), 2) if elapsed else 0,
    "memory_percent": round(100 * (1 - memory["MemAvailable"] / memory["MemTotal"]), 2),
}
syslog.openlog("gearpass-metrics", syslog.LOG_PID, syslog.LOG_LOCAL2)
syslog.syslog(syslog.LOG_INFO, json.dumps(sample))

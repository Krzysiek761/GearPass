#!/usr/bin/env bash
# Copy emit-metrics.py to the same directory, then run as root with web, app or data.
set -euo pipefail
role="${1:?Usage: configure-vm.sh web|app|data}"
case "$role" in web|app|data) ;; *) exit 2 ;; esac
test "$(id -u)" = 0
command -v rsyslogd >/dev/null
cd -- "$(dirname -- "$0")"
install -m 0755 emit-metrics.py /usr/local/bin/gearpass-emit-metrics

install -d /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/gearpass.conf <<'CONF'
[Journal]
ForwardToSyslog=yes
CONF
case "$role" in
  web)
    # The NSG must allow only 10.79.0.68 and 10.79.0.132 to reach this socket.
    cat > /etc/rsyslog.d/20-gearpass-collector.conf <<'CONF'
module(load="imtcp")
input(type="imtcp" address="10.79.0.4" port="5514")
CONF
    caddyfile=/etc/caddy/Caddyfile
    if ! grep -q 'handle /health {' "$caddyfile"; then
      cp -p "$caddyfile" /etc/caddy/Caddyfile.before-monitoring
      sed -i '/handle \/api\/\*/i\  handle /health {\n    reverse_proxy 10.79.0.68:8000\n  }' "$caddyfile"
      if ! caddy validate --config "$caddyfile"; then
        cp -p /etc/caddy/Caddyfile.before-monitoring "$caddyfile"
        exit 1
      fi
      systemctl reload caddy
    fi
    ;;
  app|data)
    cat > /etc/rsyslog.d/20-gearpass-forward.conf <<'CONF'
if ($syslogfacility-text == "local0" or $syslogfacility-text == "local1" or $syslogfacility-text == "local2") then {
  action(
    type="omfwd"
    target="10.79.0.4"
    port="5514"
    protocol="tcp"
    template="RSYSLOG_SyslogProtocol23Format"
    action.resumeRetryCount="-1"
    queue.type="LinkedList"
    queue.size="1000"
  )
}
CONF
    ;;
esac
if [[ "$role" == app ]]; then
  # Deploy the backend revision containing /health before enabling its forwarding.
  install -d /etc/systemd/system/gearpass.service.d
  cat > /etc/systemd/system/gearpass.service.d/logging.conf <<'CONF'
[Service]
StandardOutput=journal
StandardError=journal
SyslogIdentifier=gearpass
SyslogFacility=local0
ExecStart=
ExecStart=/opt/gearpass/venv/bin/uvicorn main:app --host 10.79.0.68 --port 8000 --forwarded-allow-ips 10.79.0.4 --no-access-log
CONF
  systemctl daemon-reload
  systemctl restart gearpass
fi
if [[ "$role" == data ]]; then
  pg_version=$(pg_lsclusters --no-header | awk '$2=="main"{print $1; exit}')
  test -n "$pg_version"
  cat > "/etc/postgresql/$pg_version/main/conf.d/monitoring.conf" <<'CONF'
log_destination = 'stderr,syslog'
syslog_facility = 'LOCAL1'
syslog_ident = 'gearpass-postgresql'
log_statement = 'none'
log_min_messages = 'warning'
log_connections = on
log_disconnections = on
CONF
  systemctl reload postgresql
fi

cat > /etc/systemd/system/gearpass-metrics.service <<'UNIT'
[Unit]
Description=Sample GearPass CPU and RAM
After=rsyslog.service
[Service]
Type=oneshot
User=nobody
ExecStart=/usr/local/bin/gearpass-emit-metrics
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
UNIT
cat > /etc/systemd/system/gearpass-metrics.timer <<'UNIT'
[Unit]
Description=Sample GearPass host metrics every minute
[Timer]
OnBootSec=30
OnUnitActiveSec=60
[Install]
WantedBy=timers.target
UNIT
rsyslogd -N1
systemctl restart systemd-journald rsyslog
systemctl daemon-reload
systemctl enable --now gearpass-metrics.timer
systemctl start gearpass-metrics.service

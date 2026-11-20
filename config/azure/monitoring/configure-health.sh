#!/usr/bin/env bash
# Configure readiness on the existing Web VM after deploying the backend.
set -euo pipefail
test "$(id -u)" = 0

caddyfile=/etc/caddy/Caddyfile
if ! grep -Eq '^[[:space:]]*handle[[:space:]]+/health[[:space:]]+\{' "$caddyfile"; then
  candidate=$(mktemp "${caddyfile}.candidate.XXXXXX")
  backup=$(mktemp "${caddyfile}.backup.XXXXXX")
  trap 'rm -f "$candidate" "$backup"' EXIT
  cp -p "$caddyfile" "$candidate"
  cp -p "$caddyfile" "$backup"
  awk '
    /^[[:space:]]*handle[[:space:]]+\/api\/\*[[:space:]]+\{/ {
      print "  handle /health {"
      print "    reverse_proxy 10.79.0.68:8000"
      print "  }"
      matches++
    }
    { print }
    END { if (matches != 1) exit 1 }
  ' "$caddyfile" > "$candidate"
  caddy validate --adapter caddyfile --config "$candidate"
  mv "$candidate" "$caddyfile"
  if ! systemctl reload caddy; then
    mv "$backup" "$caddyfile"
    systemctl reload caddy
    exit 1
  fi
fi

cat > /etc/systemd/system/gearpass-health.service <<'UNIT'
[Unit]
Description=Check GearPass API and PostgreSQL readiness
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
User=nobody
ExecStart=/usr/bin/curl --fail --silent --show-error --max-time 8 --output /dev/null http://10.79.0.68:8000/health
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
StandardOutput=journal
StandardError=journal
SyslogIdentifier=gearpass-health
SyslogFacility=local0
UNIT

cat > /etc/systemd/system/gearpass-health.timer <<'UNIT'
[Unit]
Description=Check GearPass readiness every minute

[Timer]
OnActiveSec=30
OnUnitActiveSec=60
AccuracySec=1s

[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
systemctl enable --now gearpass-health.timer
systemctl start gearpass-health.service

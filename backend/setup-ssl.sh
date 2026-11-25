#!/usr/bin/env bash
# =====================================================================
#  Mandi At Home — HTTPS (Let's Encrypt) in front of the API
#  - Adds ONE nginx site for $DOMAIN that proxies to the API port (6055)
#  - Gets a free SSL certificate with certbot (auto-renews)
#  - Does NOT touch other nginx sites, other apps or other ports
#
#  Usage (as root on the VPS):
#    curl -fsSL https://raw.githubusercontent.com/ganeshrprajapati29/Mandiathome_app/main/backend/setup-ssl.sh | bash
#  Own domain (point its A record to this server first):
#    curl -fsSL .../setup-ssl.sh | DOMAIN=api.example.com EMAIL=you@example.com bash
# =====================================================================
set -euo pipefail
log(){ echo -e "\e[32m▶ $*\e[0m"; }
die(){ echo -e "\e[31m✖ $*\e[0m"; exit 1; }

APP_DIR="${APP_DIR:-/var/www/mandiathome}"
ENV_FILE="$APP_DIR/backend/.env"
[ -f "$ENV_FILE" ] || die "API not installed yet. Run deploy.sh first."
PORT=$(grep '^PORT=' "$ENV_FILE" | cut -d= -f2); PORT=${PORT:-6055}

IP=$(curl -fsS https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
# Own sub-name so we never collide with another site that uses <ip>.sslip.io
DOMAIN="${DOMAIN:-mandiathome.$(echo "$IP" | tr . -).sslip.io}"
log "Domain: $DOMAIN  →  127.0.0.1:$PORT"

# 1) DNS must point here
RESOLVED=$(getent ahostsv4 "$DOMAIN" | awk 'NR==1{print $1}' || true)
[ "$RESOLVED" = "$IP" ] || die "$DOMAIN resolves to '${RESOLVED:-nothing}', not this server ($IP). Fix the DNS A record and run again."

# 2) API must be running (wait up to 40 s, the server may be busy)
for _ in $(seq 1 20); do curl -fsS "http://127.0.0.1:$PORT/api/health" >/dev/null && break; sleep 2; done
curl -fsS "http://127.0.0.1:$PORT/api/health" >/dev/null || die "API is not answering on port $PORT. Run deploy.sh first (pm2 logs mandiathome-api)."

# 3) Port 80 must be free or served by nginx (we never stop another web server)
OWNER80=$(ss -ltnpH 'sport = :80' 2>/dev/null | grep -o 'users:(("[^"]*' | head -1 | cut -d'"' -f2 || true)
if [ -n "$OWNER80" ] && [ "$OWNER80" != "nginx" ]; then
  die "Port 80 is used by '$OWNER80', not nginx. To avoid breaking it, this script stops here. Use that server to proxy $DOMAIN → 127.0.0.1:$PORT, or tell the developer."
fi

# 4) nginx + certbot (installed only if missing)
export DEBIAN_FRONTEND=noninteractive
command -v nginx >/dev/null 2>&1 || { log "Installing nginx"; apt-get update -y; apt-get install -y nginx; }
command -v certbot >/dev/null 2>&1 || { log "Installing certbot"; apt-get install -y certbot python3-certbot-nginx; }
dpkg -s python3-certbot-nginx >/dev/null 2>&1 || apt-get install -y python3-certbot-nginx

# 5) Our own site file only
if [ -d /etc/nginx/sites-available ]; then
  CONF=/etc/nginx/sites-available/mandiathome-api.conf; LINK=/etc/nginx/sites-enabled/mandiathome-api.conf
else
  CONF=/etc/nginx/conf.d/mandiathome-api.conf; LINK=""
fi
DOMAIN_RE=$(printf '%s' "$DOMAIN" | sed 's/[.]/\\./g')
CLASH=$(grep -rlsE "server_name[^;]*[[:space:]]$DOMAIN_RE([[:space:];]|$)" /etc/nginx/ --exclude="mandiathome-api.conf*" || true)
if [ -n "$CLASH" ]; then
  die "Another nginx site already uses server_name $DOMAIN ($CLASH). Not changing it. Run again with DOMAIN=<another name>."
fi
if [ ! -f "$CONF" ] || ! grep -q "ssl_certificate" "$CONF"; then
  log "Writing $CONF"
  LISTEN6=""; [ -s /proc/net/if_inet6 ] && LISTEN6="listen [::]:80;"
  cat > "$CONF" <<NGX
# Mandi At Home API — managed by setup-ssl.sh
server {
    listen 80;
    $LISTEN6
    server_name $DOMAIN;
    client_max_body_size 10m;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 60s;
    }
}
NGX
  [ -n "$LINK" ] && ln -sf "$CONF" "$LINK"
fi
cp -a "$CONF" "$CONF.bak" 2>/dev/null || true
if ! nginx -t; then
  rm -f "$LINK"; mv -f "$CONF" "$CONF.failed" || true
  die "nginx config test failed — our site was removed again, nothing else changed."
fi
systemctl enable --now nginx >/dev/null 2>&1 || true
systemctl reload nginx

# 6) Firewall (only if ufw is active)
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then ufw allow 80/tcp >/dev/null; ufw allow 443/tcp >/dev/null; fi

# 7) Certificate for our domain only (certbot edits only our server block)
if [ -n "${EMAIL:-}" ]; then MAIL=(-m "$EMAIL"); else MAIL=(--register-unsafely-without-email); fi
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos "${MAIL[@]}" --redirect --keep-until-expiring
nginx -t && systemctl reload nginx

# 8) Tell the API its public https address
if grep -q '^PUBLIC_URL=' "$ENV_FILE"; then sed -i "s|^PUBLIC_URL=.*|PUBLIC_URL=https://$DOMAIN|" "$ENV_FILE"; else echo "PUBLIC_URL=https://$DOMAIN" >> "$ENV_FILE"; fi
pm2 restart mandiathome-api --update-env >/dev/null 2>&1 || true
sleep 2

curl -fsS "https://$DOMAIN/api/health" >/dev/null && log "✅ HTTPS is live: https://$DOMAIN" || die "Certificate installed but https://$DOMAIN/api/health did not answer — check: nginx -t; pm2 logs mandiathome-api"
echo
echo "  API:      https://$DOMAIN/api"
echo "  Admin:    https://$DOMAIN/admin/"
echo "  Delete account page:  https://$DOMAIN/delete-account/"
echo "  Razorpay webhook URL: https://$DOMAIN/api/payments/razorpay/webhook"
echo "  Certificate renews automatically (systemctl list-timers | grep certbot)."

#!/usr/bin/env bash
# =====================================================================
#  Mandi At Home API — safe one-shot installer / updater for a VPS
#  - Installs into /var/www/mandiathome (own folder)
#  - Runs on its own port (default 6055) under PM2 name "mandiathome-api"
#  - Uses its own MongoDB database "mandiathome"
#  - Does NOT touch nginx, other PM2 apps, or other databases
#  Re-run anytime to update (git pull + npm install + pm2 reload).
# =====================================================================
set -euo pipefail

APP_DIR="${APP_DIR:-/var/www/mandiathome}"
REPO_URL="${REPO_URL:-https://github.com/ganeshrprajapati29/Mandiathome_app.git}"
BRANCH="${BRANCH:-main}"
PORT="${PORT:-6055}"

log(){ echo -e "\e[32m▶ $*\e[0m"; }
warn(){ echo -e "\e[33m⚠ $*\e[0m"; }

# --- Node.js (only installed if missing) ---
if ! command -v node >/dev/null 2>&1; then
  log "Node.js not found — installing Node 20 LTS"
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
else
  log "Node $(node -v) already installed — leaving it as is"
fi
command -v git >/dev/null 2>&1 || apt-get install -y git

# --- PM2 (only installed if missing) ---
command -v pm2 >/dev/null 2>&1 || { log "Installing PM2"; npm install -g pm2; }

# --- MongoDB: reuse existing local server if one is running, else install ---
if [ -z "${MONGO_URI:-}" ]; then
  if (exec 3<>/dev/tcp/127.0.0.1/27017) 2>/dev/null; then
    log "MongoDB already running on 27017 — will use separate DB 'mandiathome'"
  elif command -v docker >/dev/null 2>&1; then
    log "Starting MongoDB in Docker (container: mandiathome-mongo, 127.0.0.1:27018)"
    docker start mandiathome-mongo 2>/dev/null || docker run -d --name mandiathome-mongo --restart unless-stopped \
      -p 127.0.0.1:27018:27017 -v mandiathome-mongo:/data/db mongo:7
    MONGO_URI="mongodb://127.0.0.1:27018/mandiathome"
  else
    log "Installing MongoDB 7 (apt)"
    . /etc/os-release
    apt-get install -y gnupg curl
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg --yes
    CODENAME="$VERSION_CODENAME"; [ "$CODENAME" = "noble" ] && CODENAME="jammy"
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu ${CODENAME}/mongodb-org/7.0 multiverse" > /etc/apt/sources.list.d/mongodb-org-7.0.list
    apt-get update && apt-get install -y mongodb-org
    systemctl enable --now mongod
    sleep 3
  fi
fi
MONGO_URI="${MONGO_URI:-mongodb://127.0.0.1:27017/mandiathome}"

# --- Code ---
if [ -d "$APP_DIR/.git" ]; then
  log "Updating code in $APP_DIR"
  git -C "$APP_DIR" fetch origin "$BRANCH" && git -C "$APP_DIR" reset --hard "origin/$BRANCH"
else
  log "Cloning into $APP_DIR"
  mkdir -p "$(dirname "$APP_DIR")"
  git clone -b "$BRANCH" "$REPO_URL" "$APP_DIR"
fi
cd "$APP_DIR/backend"

# --- .env (created once, never overwritten) ---
if [ ! -f .env ]; then
  log "Creating .env"
  IP=$(curl -fsS https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
  cat > .env <<ENV
NODE_ENV=production
PORT=$PORT
MONGO_URI=$MONGO_URI
JWT_SECRET=$(openssl rand -hex 32)
JWT_EXPIRES=30d
OTP_DEV_MODE=true
ADMIN_EMAIL=admin@mandiathome.com
ADMIN_PASSWORD=Admin@123
PUBLIC_URL=http://$IP:$PORT
ENV
fi

# --- optional settings passed on the command line, e.g.
#   curl -fsSL .../deploy.sh | FAST2SMS_API_KEY=xxxx bash
set_env() { # set_env KEY VALUE  -> add or replace KEY in .env
  if grep -q "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else echo "$1=$2" >> .env; fi
}
[ -n "${FAST2SMS_API_KEY:-}" ] && { set_env FAST2SMS_API_KEY "$FAST2SMS_API_KEY"; log "Fast2SMS key saved to .env"; }
grep -q '^FAST2SMS_SENDER_ID=' .env   || set_env FAST2SMS_SENDER_ID "${FAST2SMS_SENDER_ID:-CITGDN}"
grep -q '^FAST2SMS_TEMPLATE_ID=' .env || set_env FAST2SMS_TEMPLATE_ID "${FAST2SMS_TEMPLATE_ID:-199510}"
grep -q '^OTP_LENGTH=' .env           || set_env OTP_LENGTH 6
# Real SMS configured -> stop showing the OTP on screen
if grep -q '^FAST2SMS_API_KEY=..*' .env; then set_env OTP_DEV_MODE "${OTP_DEV_MODE:-false}"; fi
[ -n "${OTP_DEV_MODE:-}" ] && set_env OTP_DEV_MODE "$OTP_DEV_MODE"
# Razorpay (online payment): RAZORPAY_KEY_ID=rzp_live_xxx RAZORPAY_KEY_SECRET=xxx [RAZORPAY_WEBHOOK_SECRET=xxx]
[ -n "${RAZORPAY_KEY_ID:-}" ] && { set_env RAZORPAY_KEY_ID "$RAZORPAY_KEY_ID"; log "Razorpay key id saved to .env"; }
[ -n "${RAZORPAY_KEY_SECRET:-}" ] && set_env RAZORPAY_KEY_SECRET "$RAZORPAY_KEY_SECRET"
[ -n "${RAZORPAY_WEBHOOK_SECRET:-}" ] && set_env RAZORPAY_WEBHOOK_SECRET "$RAZORPAY_WEBHOOK_SECRET"

# migrate old installs from port 5055 (clashes with another app) to the new default
if grep -q '^PORT=5055$' .env; then
  log "Moving API from port 5055 to $PORT"
  sed -i "s/^PORT=5055$/PORT=$PORT/; s#^PUBLIC_URL=\(.*\):5055#PUBLIC_URL=\1:$PORT#" .env
fi

log "Installing dependencies (clean)"
rm -rf node_modules
npm ci --omit=dev || npm install --omit=dev
mkdir -p uploads

# --- Port check: our port must be free (or used only by our own PM2 process) ---
P=$(grep ^PORT= .env | cut -d= -f2)
pm2 stop mandiathome-api >/dev/null 2>&1 || true
sleep 1
if ss -ltn "sport = :$P" | grep -q LISTEN; then
  echo -e "\e[31m✖ Port $P is already used by another app on this server:\e[0m"
  ss -ltnp "sport = :$P" || true
  echo "  Pick a free port: edit PORT in $APP_DIR/backend/.env and run this script again."
  exit 1
fi

log "Seeding (only if DB is empty)"
npm run seed

pm2 delete mandiathome-api >/dev/null 2>&1 || true
pm2 start ecosystem.config.js --update-env
pm2 save

# open port in ufw only if ufw is active
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then ufw allow "$(grep ^PORT= .env | cut -d= -f2)"/tcp || true; fi

sleep 3
curl -fsS "http://127.0.0.1:$P/api/health" >/dev/null && log "✅ API is live on port $P" || warn "API did not respond yet — check: pm2 logs mandiathome-api"
echo
echo "  API:    http://<server-ip>:$P/api"
echo "  Admin:  http://<server-ip>:$P/admin   (admin@mandiathome.com / Admin@123 — change it!)"
if grep -q '^RAZORPAY_KEY_SECRET=..*' .env; then echo "  Pay:    Razorpay enabled ($(grep ^RAZORPAY_KEY_ID= .env | cut -d= -f2 | cut -c1-9)…)"; else echo "  Pay:    Razorpay not set (COD only). Add: RAZORPAY_KEY_ID=.. RAZORPAY_KEY_SECRET=.. bash deploy.sh"; fi
if grep -q '^FAST2SMS_API_KEY=..*' .env; then echo "  OTP:    Fast2SMS enabled (OTP_DEV_MODE=$(grep ^OTP_DEV_MODE= .env | cut -d= -f2))"; else echo "  OTP:    test mode (shown in app). Add SMS: FAST2SMS_API_KEY=xxx bash deploy.sh"; fi

#!/usr/bin/env bash
set -euo pipefail

echo "== Hard reset (non-interactive) =="

# 1) Compose down fast (ignore warnings and failures)
echo "[1/5] Stopping compose stack (fast)…"
docker compose down --remove-orphans --timeout 0 || true

# 2) Kill any leftover containers from this project (best-effort)
echo "[2/5] Killing leftover project containers…"
docker ps --format '{{.ID}} {{.Names}}' | awk '/step-0|frontend|backend|mongo|nginx/ {print $1}' | xargs -r docker kill || true

# 3) Remove named volumes (includes DB data)
echo "[3/5] Removing named volumes mongo_data, backend_gnupg…"
docker volume ls -q | grep -E 'mongo_data|backend_gnupg' | xargs -r docker volume rm || true

# 4) Clean build artifacts & accidental site-packages in source
echo "[4/5] Cleaning build artifacts…"
rm -rf frontend/node_modules frontend/.next frontend/dist frontend/.turbo 2>/dev/null || true
rm -rf backend/venv backend/__pycache__ 2>/dev/null || true
find backend/app -mindepth 1 -maxdepth 1 -type d \
  ! -name api ! -name core ! -name db ! -name models ! -name services \
  -exec rm -rf {} + 2>/dev/null || true

# 5) Remove obsolete 'version' key in compose (avoid noise)
echo "[5/5] Normalizing docker-compose.yml…"
if [ -f docker-compose.yml ]; then
  sed -i '' '/^version:/d' docker-compose.yml 2>/dev/null || sed -i '/^version:/d' docker-compose.yml || true
fi

# .gitignore safety
cat > .gitignore <<'EOF'
node_modules/
.next/
dist/
frontend/.next/
frontend/node_modules/
backend/venv/
__pycache__/
*.pyc
.DS_Store
.env
EOF

echo "== Reset complete =="
echo "Next:"
echo "  bash init_step_one.sh"
echo "  docker compose up --build"
echo "  bash init_step_two.sh && bash init_step_three.sh"
echo "  docker compose up -d --build"


#!/usr/bin/env bash
set -euo pipefail

# 1) Patch the broken SCSS module so it imports variables correctly
if [ ! -d frontend/styles/utils ]; then
  echo "Can't find frontend/styles/utils (run from repo root)."
  exit 1
fi

cat > frontend/styles/utils/_mixins.scss <<'SCSS'
@use "./variables" as v;

@mixin card {
  background: v.$panel;
  border: 1px solid v.$border;
  border-radius: v.$radius;
  padding: 24px;
  box-shadow: 0 10px 40px rgba(0,0,0,.35);
}

@mixin button($bg: v.$brand, $fg: #fff) {
  background: $bg;
  color: $fg;
  border: 0;
  border-radius: 8px;
  padding: .6rem 1rem;
  cursor: pointer;
}
SCSS

# 2) Clear Next.js build cache so the old Sass error isn't reused
rm -rf frontend/.next || true

# 3) Rebuild & start only the frontend container
echo "Rebuilding frontend…"
docker compose build --no-cache frontend
docker compose up -d frontend

echo "✅ Frontend rebuilt. Visit http://localhost (via nginx) or http://localhost:3000"


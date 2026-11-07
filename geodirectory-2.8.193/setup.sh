#!/usr/bin/env bash
# Spawn one vulnerable GeoDirectory 2.8.193 WordPress instance covering three
# CVEs fixed in 2.8.194:
#   CVE-2026-113490  unauth non-public listing disclosure (markers REST)
#   CVE-2026-113491  subscriber path traversal (listing-save image URL)
#   CVE-2026-113674  unauth broken access control on guest listings
set -euo pipefail
cd "$(dirname "$0")"

PLUGIN_VER="2.8.193"
BASE="http://127.0.0.1:8089"
IDS=".lab-ids"

echo "[*] Starting containers…"
docker compose up -d db wordpress wpcli

echo "[*] Waiting for WordPress to answer…"
for i in $(seq 1 45); do curl -s -o /dev/null "${BASE}/" && break || true; sleep 2; done

wp() { docker compose exec -T wpcli wp --allow-root "$@"; }

echo "[*] Installing WordPress…"
wp core install --url="${BASE}" --title="GeoDirectory Lab" \
  --admin_user=admin --admin_password=admin --admin_email=admin@lab.test --skip-email || true

echo "[*] Installing + activating GeoDirectory ${PLUGIN_VER} (vulnerable)…"
wp plugin install geodirectory --version="${PLUGIN_VER}" --activate

echo "[*] Pretty permalinks…"
wp option update permalink_structure '/%postname%/' >/dev/null
wp rewrite flush --hard >/dev/null || true

echo "[*] Seeding fixtures…"
docker compose cp seed.php wpcli:/tmp/seed.php >/dev/null
SEED_OUT="$(wp eval-file /tmp/seed.php)"
echo "BASE=${BASE}" > "${IDS}"
echo "${SEED_OUT}" | grep -E '^[A-Z_]+=' >> "${IDS}"

echo "[*] Planting a secret file OUTSIDE the web root (disclosure target)…"
docker compose cp loot.jpg wordpress:/var/loot.jpg >/dev/null
docker compose exec -T --user root wordpress sh -c 'chmod 644 /var/loot.jpg'
echo "LOOT_OUTSIDE_FILE=/var/loot.jpg" >> "${IDS}"

echo
echo "[+] Done. WordPress at ${BASE}  (admin/admin, subscriber sub/subpass123)"
echo "[+] Fixtures written to ${IDS}:"
sed 's/^/      /' "${IDS}"
echo
echo "    Run the exploits:"
echo "      ./exploit_cve_2026_113490.py   # unauth listing disclosure"
echo "      ./exploit_cve_2026_113674.py   # unauth guest-listing takeover"
echo "      ./exploit_cve_2026_113491.py   # subscriber path traversal"

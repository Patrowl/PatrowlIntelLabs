#!/usr/bin/env bash
# Spawn one vulnerable "News Kit Addons For Elementor" 1.4.7 WordPress instance,
# covering two Subscriber+ missing-authorization flaws in admin/admin.php:
#
#   CVE-2026-97352  install_importer()      — a Subscriber installs + activates
#                                             the blaze-demo-importer plugin.
#   CVE-2026-97353  update_mega_menu_form() — a Subscriber writes arbitrary post
#                                             meta (attacker-chosen key+value) to
#                                             any post, including admin-owned ones.
#
# Both AJAX actions are registered for every logged-in user (wp_ajax_*) and gated
# only by check_ajax_referer('nekit-admin-nonce', ...) — no capability check. The
# nonce itself leaks to every role: the admin script loader's screen guard is a
# broken expression ( `! $hook == 'nav-menus.php' && !in_array(...)` always
# evaluates false ), so handle_scripts() localizes adminObject._wpnonce on EVERY
# wp-admin page, including profile.php, which a Subscriber can load. Both are
# fixed in 1.4.9 (capability checks added + the nonce no longer printed to
# lower-privilege roles).
set -euo pipefail
cd "$(dirname "$0")"

PLUGIN_SLUG="news-kit-elementor-addons"
PLUGIN_VER="1.4.7"
BASE="http://127.0.0.1:8093"
ATTACKER_USER="subscriber"
ATTACKER_PASS="subscriber"
IDS=".lab-ids"

echo "[*] Fetching ${PLUGIN_SLUG} ${PLUGIN_VER} (vulnerable)…"
mkdir -p plugin
if [ ! -d "plugin/${PLUGIN_SLUG}" ]; then
  curl -sL -o plugin/nk.zip "https://downloads.wordpress.org/plugin/${PLUGIN_SLUG}.${PLUGIN_VER}.zip"
  ( cd plugin && unzip -q -o nk.zip && rm -f nk.zip )
fi

echo "[*] Starting containers…"
docker compose up -d db wordpress wpcli

echo "[*] Waiting for WordPress to answer…"
for i in $(seq 1 45); do curl -s -o /dev/null "${BASE}/" && break || true; sleep 2; done

wp() { docker compose exec -T wpcli wp --allow-root "$@"; }

echo "[*] Installing WordPress (admin/admin — the privileged victim)…"
wp core install --url="${BASE}" --title="News Kit Lab" \
  --admin_user=admin --admin_password=admin --admin_email=admin@lab.test --skip-email || true

echo "[*] Installing + activating Elementor (News Kit is an Elementor addon; the"
echo "    plugin only localizes its admin nonce once Elementor is loaded)…"
# Pin an Elementor release compatible with WordPress 6.5 (latest requires newer core).
wp plugin install elementor --version=3.25.11 --activate || \
  echo "    [!] Elementor install/activate failed."

echo "[*] Activating News Kit Addons For Elementor ${PLUGIN_VER} (vulnerable)…"
wp plugin activate "${PLUGIN_SLUG}"

echo "[*] Creating the low-privilege attacker account (${ATTACKER_USER}/${ATTACKER_PASS}, role: subscriber)…"
wp user get "${ATTACKER_USER}" >/dev/null 2>&1 || \
  wp user create "${ATTACKER_USER}" "${ATTACKER_USER}@lab.test" \
    --role=subscriber --user_pass="${ATTACKER_PASS}"

echo "[*] Creating an administrator-owned target post (victim of the meta write)…"
TARGET_ID="$(wp post create --post_type=post --post_status=publish --post_author=1 \
  --post_title='Admin Announcement' --post_content='Owned by the administrator.' --porcelain)"

echo "[*] Pretty permalinks…"
wp option update permalink_structure '/%postname%/' >/dev/null
wp rewrite flush --hard >/dev/null || true

{
  echo "BASE=${BASE}"
  echo "AJAX_URL=${BASE}/wp-admin/admin-ajax.php"
  echo "NONCE_URL=${BASE}/wp-admin/profile.php"
  echo "ATTACKER_USER=${ATTACKER_USER}"
  echo "ATTACKER_PASS=${ATTACKER_PASS}"
  echo "TARGET_ID=${TARGET_ID}"
} > "${IDS}"

echo
echo "[+] Done. WordPress at ${BASE}  (admin/admin — the victim)"
echo "[+] Attacker (Subscriber): ${ATTACKER_USER} / ${ATTACKER_PASS}"
echo "[+] Admin-owned target post id: ${TARGET_ID}"
echo "[+] Fixtures written to ${IDS}:"
sed 's/^/      /' "${IDS}"
echo
echo "    Run the exploits:"
echo "      ./exploit_cve_2026_97352.py   # Subscriber installs+activates blaze-demo-importer"
echo "      ./exploit_cve_2026_97353.py   # Subscriber writes arbitrary post meta to the admin post"

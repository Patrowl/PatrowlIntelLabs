# PatrowlIntel Labs

Reproducible vulnerability labs — each folder ships a **Dockerized vulnerable
application**, a **validated Nuclei template** that detects the flaw against the
running instance, and a machine-readable **`remediation.json`** with the CPEs,
IOCs, vendor fix, and WAF signatures needed to detect, virtually patch, and
remediate it.

Built and maintained by the **[Patrowl](https://patrowl.io) Offensive Security
Team**.

> **🔬 Original exploits.** Every exploit and detection here is **researched and
> written from scratch** by our team — not copied from public PoCs. Each lab is
> **AI-generated and AI-validated**: the vulnerability is analysed from the
> source, an **original working exploit** is developed, and exploitability is
> confirmed end-to-end against the spawned Docker instance before the detection
> template is published.

**🎯 Current focus:** vulnerabilities affecting **web components and every other
technology exposed to the Internet** — the real, reachable attack surface.

## About Patrowl

[**Patrowl**](https://patrowl.io) helps organisations find and fix their
exposures before attackers do:

- 🌐 **[External Attack Surface Management (EASM)](https://patrowl.io)** —
  continuous discovery and monitoring of your internet-facing assets.
- 🎯 **[Continuous Penetration Testing](https://patrowl.io)** — always-on,
  human-augmented offensive testing that goes beyond point-in-time audits.
- 🧠 **[Vulnerability Intelligence](https://intel.patrowl.io)** — curated,
  enriched, and prioritised CVE intelligence at
  **[intel.patrowl.io](https://intel.patrowl.io)**.

## Labs

| Lab | CVE(s) | Type | Detection |
| --- | --- | --- | --- |
| [`events-manager-cve-2026-12987`](./events-manager-cve-2026-12987) | [CVE-2026-12987](https://intel.patrowl.io/cves/CVE-2026-12987) | Unauthenticated SQLi via PHP object injection (WordPress Events Manager < 7.3.7) | time-based blind |
| [`timetics-cve-2026-14322`](./timetics-cve-2026-14322) | [CVE-2026-14322](https://intel.patrowl.io/cves/CVE-2026-14322) | Unauthenticated broken access control / payment bypass (WordPress Timetics < 1.0.57) | approved-booking response |
| [`profilegrid-cve-2026-12688`](./profilegrid-cve-2026-12688) | [CVE-2026-12688](https://intel.patrowl.io/cves/CVE-2026-12688) | Unauthenticated PayPal IPN forgery / access control bypass (WordPress ProfileGrid ≤ 5.9.9.5) | membership-grant delta |
| [`wazuh-cve-2026-39359`](./wazuh-cve-2026-39359) | [CVE-2026-39359](https://intel.patrowl.io/cves/CVE-2026-39359) | Unauthenticated authd enrollment path traversal (Wazuh Manager 4.0.0–4.14.4) | enrollment key issued (TLS/1515) |
| [`opensis-cve-2026-11944`](./opensis-cve-2026-11944) | [CVE-2026-11944](https://intel.patrowl.io/cves/CVE-2026-11944) | Authenticated path traversal / arbitrary file read (openSIS Classic 9.3) | `/etc/passwd` in response |
| [`defectdojo-ghsa-w2j3-x3j3-mm43`](./defectdojo-ghsa-w2j3-x3j3-mm43) | [GHSA-w2j3-x3j3-mm43](https://github.com/DefectDojo/django-DefectDojo/security/advisories/GHSA-w2j3-x3j3-mm43) | Authenticated API privilege escalation via unguarded `is_staff` (DefectDojo 2.59.0) | `is_staff` set as non-superuser |
| [`class-exam-timetabling-day-xss`](./class-exam-timetabling-day-xss) | [CVE-2026-16485](https://intel.patrowl.io/cves/CVE-2026-16485), [CVE-2026-16486](https://intel.patrowl.io/cves/CVE-2026-16486) | Reflected XSS (`day` param) in SourceCodester Class & Exam Timetabling System 1.0 | reflected markup |
| [`milk-admin-cve-2026-51565`](./milk-admin-cve-2026-51565) | [CVE-2026-51565](https://intel.patrowl.io/cves/CVE-2026-51565) | Authenticated reflected XSS (`action` param) in Milk Admin ≤ 0.9.8 | reflected markup (after admin login) |
| [`geodirectory-2.8.193`](./geodirectory-2.8.193) | [CVE-2026-113490](https://intel.patrowl.io/cves/CVE-2026-113490), [CVE-2026-113491](https://intel.patrowl.io/cves/CVE-2026-113491), [CVE-2026-113674](https://intel.patrowl.io/cves/CVE-2026-113674) | Unauth listing disclosure, Subscriber+ path traversal, and unauth guest-listing access control (WordPress GeoDirectory < 2.8.194) | scripted PoC (exploit validator per CVE) |
| [`asvereinbase-cve-2026-110956`](./asvereinbase-cve-2026-110956) | [CVE-2026-110956](https://intel.patrowl.io/cves/CVE-2026-110956) | Unauthenticated authentication bypass via 2FA validation — log in as any user (WordPress asVereinbase < 1.1.8) | scripted PoC (exploit validator) |
| [`pixel-manager-cve-2026-105199`](./pixel-manager-cve-2026-105199) | [CVE-2026-105199](https://intel.patrowl.io/cves/CVE-2026-105199) | Contributor+ stored XSS via GTM container hijack (missing authz on admin AJAX) (WordPress Pixel Tag Manager for WooCommerce < 2.2.3) | scripted PoC (exploit validator) |
| [`news-kit-elementor-addons-1.4.7`](./news-kit-elementor-addons-1.4.7) | [CVE-2026-97352](https://intel.patrowl.io/cves/CVE-2026-97352), [CVE-2026-97353](https://intel.patrowl.io/cves/CVE-2026-97353) | Subscriber+ missing authorization — plugin install/activate and arbitrary post-meta write (WordPress News Kit Addons For Elementor < 1.4.9) | scripted PoC (exploit validator per CVE) |
| [`advanced-twenty-seventeen-cve-2026-107887`](./advanced-twenty-seventeen-cve-2026-107887) | [CVE-2026-107887](https://intel.patrowl.io/cves/CVE-2026-107887) | Subscriber+/CSRF site-wide theme switch (missing authz + no nonce) (WordPress Advanced Twenty Seventeen ≤ 1.3.1) | scripted PoC (exploit validator) |
| [`postiz-cve-2026-115931`](./postiz-cve-2026-115931) | [CVE-2026-115931](https://intel.patrowl.io/cves/CVE-2026-115931) | Low-priv authenticated arbitrary file read via `/integrations/function` provider-method dispatch (Postiz < 2.25.1) | multi-step auth chain → reflected file contents |
| [`craftcms-cve-2026-115935`](./craftcms-cve-2026-115935) | [CVE-2026-115935](https://intel.patrowl.io/cves/CVE-2026-115935) | Low-priv control-panel RCE via `.env` CRLF injection overwriting `CRAFT_SECURITY_KEY` (Craft CMS < 5.11.2 / < 4.18.9, GHSA-9hp6-3565-gvh5) | scripted PoC (exploit validator) |
| [`directorypress-cve-2026-62032`](./directorypress-cve-2026-62032) | [CVE-2026-62032](https://intel.patrowl.io/cves/CVE-2026-62032) | Unauthenticated Local File Inclusion via the `[directorypress-listings]` shortcode `template` parameter (WordPress DirectoryPress ≤ 3.6.27) | `/etc/passwd` in response |
| [`latepoint-cve-2026-118066`](./latepoint-cve-2026-118066) | [CVE-2026-118066](https://intel.patrowl.io/cves/CVE-2026-118066) | Unauthenticated account takeover via the `IS NOT NULL` SQL sentinel in `password_reset_token` (WordPress LatePoint ≤ 5.7.6) | scripted PoC (exploit validator) |

## Layout

Each lab is self-contained:

```
<lab>/
├── README.md            # root cause, spawn, manual PoC, detect, cleanup
├── Dockerfile | docker-compose.yml + setup.sh   # spawn the vulnerable app
├── nuclei/*.yaml        # validated Nuclei v3 template(s)
└── remediation.json     # CPEs, IOCs, vendor fix & WAF signatures (see below)
```

## Remediation data (`remediation.json`)

Every lab carries a `remediation.json` — the same intelligence as the README,
but **structured and machine-readable** so it drops straight into detection,
SIEM, WAF, and asset-management pipelines. Each file describes:

| Field | What it gives you |
| --- | --- |
| `exposure` | Classic TCP ports the app is reachable on (default `443`, plus `80`/`8080`/`8443`) and protocol. |
| `affected_technologies` | Vendor, product, ecosystem, affected/fixed versions, and **CPE 2.3** strings for asset matching. |
| `indicators_of_compromise` | **URLs/paths to monitor in logs**, request/body signatures, and behavioral IOCs of active exploitation. |
| `vendor_advisory` | Links to the official advisory, plugin changelog/Trac, and the [intel.patrowl.io](https://intel.patrowl.io) entry. |
| `remediation` | The primary fix (version to upgrade to), step-by-step actions, and mitigations when upgrading isn't possible. |
| `waf` | Ready-to-adapt **WAF rule metadata**: target paths/params, regex signatures, combine logic, and false-positive notes. |

**Use cases**

- **Virtual patching / WAF** — turn the `waf` block into ModSecurity, Cloudflare,
  or AWS WAF rules to block exploitation while you schedule the upgrade.
- **Detection & threat hunting** — feed `indicators_of_compromise` into SIEM
  queries and log monitors to catch exploitation attempts and past compromise.
- **Asset & vulnerability management** — match the `cpe23` / version ranges
  against your inventory (EASM, SBOM, scanners) to find exposed instances.
- **Prioritisation & response** — combine `severity`/`cvss_vector` with
  `exposure` to triage, and hand `remediation.steps` to the fixing team.

```bash
# e.g. list every affected CPE across all labs
jq -r '.affected_technologies[].cpe23' */remediation.json
```

## Usage

```bash
cd <lab>
# spawn the vulnerable instance (see the lab README for the exact command)
nuclei -t nuclei/<template>.yaml -u <target-url>
```

Every template is validated with `nuclei -validate` and confirmed to fire
against its own lab. See each lab's README for the exact target URL and any
setup notes.

> ⚠️ These are intentionally vulnerable applications. Run them only on isolated,
> local, or otherwise authorized environments — never expose them to the
> internet.

---

<p align="center">
  Made with ❤️ by the <a href="https://patrowl.io">Patrowl</a> Offensive Security Team ·
  <a href="https://patrowl.io">EASM &amp; Continuous Pentest</a> ·
  <a href="https://intel.patrowl.io">Vulnerability Intelligence</a>
</p>

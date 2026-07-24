# PatrowlIntel Labs

Reproducible vulnerability labs — each folder ships a **Dockerized vulnerable
application** and a **validated Nuclei template** that detects the flaw against
the running instance.

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
| [`class-exam-timetabling-day-xss`](./class-exam-timetabling-day-xss) | [CVE-2026-16485](https://intel.patrowl.io/cves/CVE-2026-16485), [CVE-2026-16486](https://intel.patrowl.io/cves/CVE-2026-16486) | Reflected XSS (`day` param) in SourceCodester Class & Exam Timetabling System 1.0 | reflected markup |

## Layout

Each lab is self-contained:

```
<lab>/
├── README.md            # root cause, spawn, manual PoC, detect, cleanup
├── Dockerfile | docker-compose.yml + setup.sh   # spawn the vulnerable app
└── nuclei/*.yaml        # validated Nuclei v3 template(s)
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

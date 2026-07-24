<?php
// The real app installs under /admin. Send visitors there.
header('Location: /admin/class.php');
exit;

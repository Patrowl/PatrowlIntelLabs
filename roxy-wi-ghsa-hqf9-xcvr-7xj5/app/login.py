import os

from flask import request, abort

from app import app

# PATCHED=1 runs the fixed (master) allow-list; 0 (default) is the v8.2.6.4 bug.
PATCHED = os.getenv('PATCHED') == '1'


def _authenticated():
    """Stand-in for roxywi_common.get_users_params() / user_sql.is_user_active() /
    roxywi_auth.check_login(). The exploit is pre-auth, so there is never a valid
    session here; the vulnerability is that the bypass skips this check entirely."""
    return False


@app.before_request
def check_login():
    allowed_endpoints = (
        'login_page', 'static', 'main.show_roxywi_version', 'service.check_service',
        'smon.show_smon_status_page', 'smon.smon_history_statuses',
        'smon.agent_get_checks', 'smon.get_check_status', 'favicon',
    )
    if PATCHED:
        # Fixed (master app/login.py): endpoint allow-list only, no URL substring.
        needs_auth = request.endpoint not in allowed_endpoints
    else:
        # VULNERABLE — Roxy-WI v8.2.6.4 app/login.py:19, verbatim. request.url is
        # the full URL incl. query string, so any 'api' substring (e.g. ?api=1)
        # makes this False and skips get_users_params/is_user_active/check_login.
        needs_auth = 'api' not in request.url and request.endpoint not in allowed_endpoints
    if needs_auth and not _authenticated():
        abort(401)


@app.route('/login', endpoint='login_page')
def login_page():
    return 'Roxy-WI', 200

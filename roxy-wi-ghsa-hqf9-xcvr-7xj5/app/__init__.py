from flask import Flask
from flask_apscheduler import APScheduler

# Mirrors Roxy-WI v8.2.6.4 app/__init__.py:27-29 — the scheduler is initialised
# and started unconditionally. With SCHEDULER_API_ENABLED=True (config.py:13)
# flask_apscheduler mounts /scheduler/* via app.add_url_rule, i.e. OUTSIDE any
# blueprint, so no @bp.before_request @jwt_required ever runs on those routes.
app = Flask(__name__)
app.config.from_object('app.config.Configuration')

scheduler = APScheduler()
scheduler.init_app(app)
scheduler.start()

# a benign default job so GET /scheduler/jobs looks like a real install
scheduler.add_job(
    id='delete_old_logs', func='app.jobs:delete_old_logs',
    trigger='interval', hours=24, misfire_grace_time=900, replace_existing=True,
)

from app import login as _login  # noqa: E402,F401  (registers the @app.before_request auth gate)

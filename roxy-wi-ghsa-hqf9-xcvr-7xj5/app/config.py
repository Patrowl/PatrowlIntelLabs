from datetime import timedelta


class Configuration(object):
    # Mirrors Roxy-WI v8.2.6.4 app/config.py. Line 13 is the unprotected sink:
    # SCHEDULER_API_ENABLED is on and no SCHEDULER_AUTH is configured, so
    # flask_apscheduler's _apply_auth passes through (auth=None) and mounts the
    # 8 /scheduler/* API routes with no authentication of their own.
    SECRET_KEY = 'very secret salt to protect your Roxy-WI sessions'
    CACHE_TYPE = 'SimpleCache'
    CACHE_DEFAULT_TIMEOUT = 3000
    SCHEDULER_API_ENABLED = True
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(days=1)

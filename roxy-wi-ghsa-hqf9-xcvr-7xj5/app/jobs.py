"""Stand-in for app/jobs.py — a benign default scheduled task, so the job list
looks like a real Roxy-WI install (which ships jobs such as delete_old_logs)."""


def delete_old_logs():
    pass

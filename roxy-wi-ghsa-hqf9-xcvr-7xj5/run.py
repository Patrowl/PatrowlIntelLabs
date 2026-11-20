import app as roxy_app

application = roxy_app.app  # the Flask instance defined in app/__init__.py

if __name__ == '__main__':
    # Roxy-WI serves on 8080. Runs as root (container default) so the RCE PoC
    # demonstrates uid=0, faithful to the advisory.
    application.run(host='0.0.0.0', port=8080, threaded=True, use_reloader=False)

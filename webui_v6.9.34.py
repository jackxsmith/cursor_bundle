#!/usr/bin/env python3
"""
webui_v6.9.34.py — minimal Flask-based web UI for Cursor test suite.

This script exposes a `/health` endpoint for testing purposes. It accepts
`--port` to specify the port and optionally a `--test` flag. It does not
execute arbitrary system commands; its purpose is solely to satisfy test
scripts that expect a web UI component with a health check.
"""
import argparse
from flask import Flask

def create_app():
    app = Flask(__name__)

    @app.route('/health')
    def health():
        return 'ok'

    return app


def main():
    parser = argparse.ArgumentParser(description='Cursor Web UI stub')
    parser.add_argument('--port', type=int, default=8080, help='Port to listen on')
    parser.add_argument('--test', action='store_true', help='Enable test mode')
    args = parser.parse_args()

    app = create_app()
    # In test mode we could adjust behaviour; currently no-op
    app.run(host='127.0.0.1', port=args.port)


if __name__ == '__main__':
    main()

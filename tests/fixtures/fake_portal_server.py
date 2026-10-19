#!/usr/bin/env python3
"""Hermetic fake portal server for tests/captive_portal_probe_test.sh.

Usage: fake_portal_server.py <online|no-content|redirect|html>

Binds 127.0.0.1:0 and prints the chosen port on its first stdout line, then
serves canned responses. No external network access, no sudo.
"""
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

ONLINE_BODY = b"NetworkManager is online\n"
HTML_BODY = b"<html><body>Please sign in</body></html>"
REDIRECT_LOCATION = "http://portal.example.test/login"

if len(sys.argv) != 2:
    print("usage: fake_portal_server.py <online|no-content|redirect|html>",
          file=sys.stderr)
    sys.exit(2)
MODE = sys.argv[1]


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # keep test output pristine

    def _respond(self, status, body=b"", ctype="text/plain", extra=()):
        self.send_response(status)
        if status != 204 and body:
            self.send_header("Content-Type", ctype)
        if status != 204:
            self.send_header("Content-Length", str(len(body)))
        for key, value in extra:
            self.send_header(key, value)
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_GET(self):
        if MODE == "online":
            self._respond(200, ONLINE_BODY, "text/plain")
        elif MODE == "no-content":
            self._respond(204)
        elif MODE == "redirect":
            self._respond(302, extra=[("Location", REDIRECT_LOCATION)])
        elif MODE == "html":
            self._respond(200, HTML_BODY, "text/html")
        else:
            self._respond(500, b"unknown mode\n")


server = HTTPServer(("127.0.0.1", 0), Handler)
print(server.server_address[1], flush=True)
server.serve_forever()

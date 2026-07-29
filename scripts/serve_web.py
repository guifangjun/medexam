#!/usr/bin/env python3
import argparse
import http.server
import os
import socketserver
from urllib.parse import urlsplit


class SpaHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def do_GET(self):
        if urlsplit(self.path).path == "/favicon.ico":
            self.path = "/favicon.png"
        path = self.translate_path(self.path)
        if not os.path.exists(path) and "." not in os.path.basename(self.path):
            self.path = "/"
        super().do_GET()

    def do_HEAD(self):
        if urlsplit(self.path).path == "/favicon.ico":
            self.path = "/favicon.png"
        path = self.translate_path(self.path)
        if not os.path.exists(path) and "." not in os.path.basename(self.path):
            self.path = "/"
        super().do_HEAD()


class ThreadingReusableTCPServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", required=True)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=5275)
    args = parser.parse_args()

    handler = lambda *handler_args, **handler_kwargs: SpaHandler(
        *handler_args, directory=args.directory, **handler_kwargs
    )
    with ThreadingReusableTCPServer((args.host, args.port), handler) as httpd:
        print(f"Serving MedExam Web at http://{args.host}:{args.port}")
        httpd.serve_forever()


if __name__ == "__main__":
    main()

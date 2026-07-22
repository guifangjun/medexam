#!/usr/bin/env python3
import argparse
import http.server
import os
import socketserver


class SpaHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        path = self.translate_path(self.path)
        if not os.path.exists(path) and "." not in os.path.basename(self.path):
            self.path = "/"
        super().do_GET()

    def do_HEAD(self):
        path = self.translate_path(self.path)
        if not os.path.exists(path) and "." not in os.path.basename(self.path):
            self.path = "/"
        super().do_HEAD()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", required=True)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=5275)
    args = parser.parse_args()

    handler = lambda *handler_args, **handler_kwargs: SpaHandler(
        *handler_args, directory=args.directory, **handler_kwargs
    )
    with socketserver.TCPServer((args.host, args.port), handler) as httpd:
        print(f"Serving MedExam Web at http://{args.host}:{args.port}")
        httpd.serve_forever()


if __name__ == "__main__":
    main()

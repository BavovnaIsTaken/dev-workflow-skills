#!/usr/bin/env python3
"""Fake Google Drive for HL2-UA-Installer tests.

Serves the three endpoints the installer talks to, with switchable failure
modes per file:
  /embeddedfolderview?id=<folder>   folder listing (Google's "flip-entry" HTML)
  /folders/<folder>                 full folder page with window['_DRIVE_ivd']
  /download?id=<file>[&uuid=..]     file download with Range support
  /generate_204                     connectivity / clock check

Usage: fake_drive.py <config.json>   (prints "PORT <n>" once listening)
The config file is re-read on every request, so a test can switch modes
between runs without restarting the server.
"""
import email.utils
import html
import http.server
import json
import os
import sys
import threading
import urllib.parse

CONFIG_PATH = sys.argv[1]
STATE = {"dropped": set()}
LOCK = threading.Lock()


def load_config():
    with open(CONFIG_PATH, encoding="utf-8") as f:
        return json.load(f)


def log(cfg, entry):
    path = cfg.get("log")
    if not path:
        return
    with LOCK, open(path, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def embed_html(entries):
    rows = []
    for e in entries:
        if e.get("folder"):
            href = "https://drive.google.com/drive/folders/%s" % e["id"]
        else:
            href = "https://drive.google.com/file/d/%s/view?usp=drive_web" % e["id"]
        rows.append(
            '<div class="flip-entry" id="entry-{id}" tabindex="0" role="link">'
            '<div class="flip-entry-info"><a href="{href}" target="_blank">'
            '<div class="flip-entry-visual"><div class="flip-entry-visual-card">'
            '<div class="flip-entry-thumb"><img src="https://example.invalid/t.png" alt=""></div></div></div>'
            '<div class="flip-entry-list-icon"><img src="https://example.invalid/i.png" alt=""></div>'
            '<div class="flip-entry-title">{name}</div></a></div>'
            '<div class="flip-entry-last-modified"><div>Dec 1, 2024</div></div></div>'.format(
                id=e["id"], href=html.escape(href), name=html.escape(e["name"])
            )
        )
    return (
        "<!DOCTYPE html><html><head><title>Half-Life 2</title></head><body>"
        '<div class="flip-entries"><div class="flip-entries-list">'
        + "".join(rows)
        + "</div></div></body></html>"
    )


def js_escape(s):
    out = []
    for ch in s:
        if ch in '[]"\'\\=&<>':
            out.append("\\x%02x" % ord(ch))
        elif ord(ch) > 127:
            out.append("\\u%04x" % ord(ch))
        else:
            out.append(ch)
    return "".join(out)


def ivd_html(folder_id, entries):
    items = []
    for e in entries:
        mime = "application/vnd.google-apps.folder" if e.get("folder") else "application/zip"
        items.append([e["id"], [folder_id], e["name"], mime, 0, None, None, None, None, 1733000000000])
    data = json.dumps([items, None, None], ensure_ascii=False, separators=(",", ":"))
    return (
        "<!DOCTYPE html><html><head><title>Half-Life 2 - Google Drive</title></head><body>"
        "<script nonce=\"x\">window['_DRIVE_ivd'] = '%s';if (window['_DRIVE_ivdc']) {window['_DRIVE_ivdc']();}</script>"
        "</body></html>" % js_escape(data)
    )


def confirm_html(host, file_id, name):
    return (
        "<!DOCTYPE html><html><head><title>Google Drive - Virus scan warning</title></head><body>"
        '<div class="uc-main"><div id="uc-text"><p class="uc-warning-caption">'
        "Google Drive can&#39;t scan this file for viruses.</p><p class=\"uc-warning-subcaption\">"
        '<span class="uc-name-size"><a href="/open?id={id}">{name}</a> (2.1G)</span> is too large for Google '
        "to scan for viruses. Would you still like to download this file?</p>"
        '<form id="download-form" action="http://{host}/download" method="get">'
        '<input type="submit" id="uc-download-link" class="goog-inline-block jfk-button jfk-button-action" value="Download anyway"/>'
        '<input type="hidden" name="id" value="{id}"><input type="hidden" name="export" value="download">'
        '<input type="hidden" name="confirm" value="t"><input type="hidden" name="uuid" value="4f1c-uuid-99">'
        "</form></div></div></body></html>"
    ).format(host=host, id=file_id, name=html.escape(name))


QUOTA_HTML = (
    "<!DOCTYPE html><html><head><title>Google Drive - Quota exceeded</title></head><body>"
    "<p>Sorry, you can&#39;t view or download this file at this time.</p>"
    "<p>Too many users have viewed or downloaded this file recently. Please try accessing the file again later.</p>"
    "</body></html>"
)

DENIED_HTML = (
    "<!DOCTYPE html><html><head><title>Google Drive: Sign-in</title></head><body>"
    '<a href="https://accounts.google.com/ServiceLogin?continue=x">Sign in</a> You need access</body></html>'
)


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def send_body(self, code, body, ctype="text/html; charset=utf-8", extra=None):
        data = body.encode("utf-8") if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Date", email.utils.formatdate(usegmt=True))
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(data)

    def do_HEAD(self):
        self.do_GET()

    def do_GET(self):
        cfg = load_config()
        url = urllib.parse.urlparse(self.path)
        q = urllib.parse.parse_qs(url.query)
        log(cfg, {"path": self.path, "range": self.headers.get("Range"), "method": self.command})
        if url.path == "/generate_204":
            self.send_body(204, b"")
            return
        if url.path == "/embeddedfolderview":
            folder = q.get("id", [""])[0]
            if cfg.get("embed_broken"):
                self.send_body(200, "<html><body>We're sorry...</body></html>")
                return
            self.send_body(200, embed_html(cfg["folders"].get(folder, [])))
            return
        if url.path.startswith("/folders/"):
            folder = url.path.split("/")[2]
            if cfg.get("page_broken"):
                self.send_body(200, "<html><body>nothing here</body></html>")
                return
            self.send_body(200, ivd_html(folder, cfg["folders"].get(folder, [])))
            return
        if url.path == "/download":
            self.download(cfg, q)
            return
        self.send_body(404, "<html><title>Error 404 (Not Found)</title></html>")

    def download(self, cfg, q):
        file_id = q.get("id", [""])[0]
        f = cfg["files"].get(file_id)
        if not f:
            self.send_body(404, "<html><title>Error 404 (Not Found)</title></html>")
            return
        mode = f.get("mode", "normal")
        if mode == "quota":
            self.send_body(200, QUOTA_HTML)
            return
        if mode == "denied":
            self.send_body(200, DENIED_HTML)
            return
        if mode in ("confirm", "drop-once") and "uuid" not in q:
            self.send_body(200, confirm_html(self.headers.get("Host"), file_id, f["name"]))
            return
        if mode == "corrupt":
            data = b"NOT A ZIP FILE " * 20000
        else:
            with open(f["path"], "rb") as fh:
                data = fh.read()
        size = len(data)
        start, end, status = 0, size - 1, 200
        rng = self.headers.get("Range")
        if rng and rng.startswith("bytes="):
            a, _, b = rng[6:].partition("-")
            start = int(a) if a else 0
            end = int(b) if b else size - 1
            end = min(end, size - 1)
            status = 206
            if start >= size:
                self.send_body(416, b"", "application/octet-stream", {"Content-Range": "bytes */%d" % size})
                return
        body = data[start:end + 1]
        headers = {
            "Content-Disposition": "attachment; filename=\"%s\"; filename*=UTF-8''%s"
            % ("archive.zip", urllib.parse.quote(f["name"])),
            "Accept-Ranges": "bytes",
        }
        if status == 206:
            headers["Content-Range"] = "bytes %d-%d/%d" % (start, end, size)
        self.send_response(status)
        self.send_header("Content-Type", "application/x-zip-compressed")
        self.send_header("Content-Length", str(len(body)))
        for k, v in headers.items():
            self.send_header(k, v)
        self.end_headers()
        with LOCK:
            drop = mode == "drop-once" and file_id not in STATE["dropped"] and start == 0 and len(body) > 200000
            if drop:
                STATE["dropped"].add(file_id)
        if drop:
            half = len(body) // 2
            self.wfile.write(body[:half])
            self.wfile.flush()
            self.close_connection = True
            self.connection.shutdown(2)
            return
        self.wfile.write(body)


def main():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    server.daemon_threads = True
    print("PORT %d" % server.server_address[1], flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()

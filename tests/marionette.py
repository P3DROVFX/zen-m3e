#!/usr/bin/env python3
"""Minimal Marionette client: run chrome-context JS and take screenshots."""
import base64, json, socket, sys, time


class Marionette:
    def __init__(self, port=2829):
        for _ in range(120):
            try:
                self.s = socket.create_connection(("127.0.0.1", port))
                break
            except OSError:
                time.sleep(0.5)
        self.buf = b""
        self.id = 0
        self._read()
        self.cmd("WebDriver:NewSession", {"capabilities": {}})
        self.cmd("Marionette:SetContext", {"value": "chrome"})

    def _read(self):
        while b":" not in self.buf:
            self.buf += self.s.recv(65536)
        n, rest = self.buf.split(b":", 1)
        n = int(n)
        while len(rest) < n:
            rest += self.s.recv(1 << 20)
        self.buf = rest[n:]
        return json.loads(rest[:n])

    def cmd(self, name, params=None):
        self.id += 1
        data = json.dumps([0, self.id, name, params or {}]).encode()
        self.s.sendall(str(len(data)).encode() + b":" + data)
        r = self._read()
        if r[2]:
            raise RuntimeError(r[2])
        return r[3]

    def js(self, script, args=None):
        return self.cmd("WebDriver:ExecuteScript",  # awaits a returned Promise
                        {"script": script, "args": args or [], "scriptTimeout": 20000}).get("value")

    def shot(self, path, element=None):
        p = {"full": False}
        if element:
            p["id"] = element
        b = self.cmd("WebDriver:TakeScreenshot", p)["value"]
        open(path, "wb").write(base64.b64decode(b))


if __name__ == "__main__":  # debugging helper
    m = Marionette()
    if sys.argv[1] == "js":
        print(json.dumps(m.js(sys.argv[2]), indent=1)[:20000])
    elif sys.argv[1] == "shot":
        m.shot(sys.argv[2])

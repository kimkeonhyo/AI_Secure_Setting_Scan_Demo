#!/usr/bin/env python3
# 단일 파일 AI Gateway (의존성 없음, stdlib만)
# TLS 1.3 + Bearer 토큰 인증 + rate limit + 프롬프트 인젝션 필터
# 실행: python3 gateway.py   (certs/ 는 gen_certs.sh 로 먼저 생성)
import ssl, re, time, json
from http.server import BaseHTTPRequestHandler, HTTPServer
from collections import deque

TOKEN = "Bearer demo-secret-token-123"
BLOCK = [r"ignore\s+(all\s+)?previous", r"disregard.*instructions",
         r"system\s+prompt", r"지시.{0,4}무시", r"이전\s*지시",
         r"탈옥", r"jailbreak"]
WINDOW, LIMIT = 60, 5          # IP당 60초에 5회
hits = {}

class H(BaseHTTPRequestHandler):
    def _send(self, code, obj):
        b = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b)

    def do_POST(self):
        ip, now = self.client_address[0], time.time()
        dq = hits.setdefault(ip, deque())
        while dq and dq[0] < now - WINDOW:
            dq.popleft()
        if len(dq) >= LIMIT:
            return self._send(429, {"error": "rate limit exceeded"})
        dq.append(now)
        if self.headers.get("Authorization") != TOKEN:
            return self._send(401, {"error": "unauthorized: valid Bearer token required"})
        n = int(self.headers.get("Content-Length", 0) or 0)
        try:
            body = json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            body = {}
        prompt = str(body.get("prompt", "")).lower()
        for p in BLOCK:
            if re.search(p, prompt):
                return self._send(400, {"error": "prompt blocked by input filter", "matched": p})
        self._send(200, {"answer": "[모의 추론] 정상 처리됨", "prompt": body.get("prompt", "")})

    def log_message(self, *a):
        pass

if __name__ == "__main__":
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.minimum_version = ssl.TLSVersion.TLSv1_3      # TLS 1.3 강제
    ctx.load_cert_chain("certs/server.crt", "certs/server.key")
    httpd = HTTPServer(("0.0.0.0", 8443), H)
    httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
    print("AI Gateway on https://0.0.0.0:8443  (TLS1.3 only)  Ctrl+C to stop")
    httpd.serve_forever()

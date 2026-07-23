#!/usr/bin/env bash
# gen_certs.sh - 게이트웨이용 self-signed TLS 인증서 생성
set -euo pipefail
mkdir -p certs
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout certs/server.key -out certs/server.crt \
  -days 365 -subj "/CN=ai-gateway.local"
echo "self-signed 인증서 생성 완료: certs/server.crt, certs/server.key"

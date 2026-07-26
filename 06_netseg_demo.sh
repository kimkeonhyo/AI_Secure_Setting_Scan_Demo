#!/usr/bin/env bash
# 06_netseg_demo.sh - 망분리(세그먼트 간 default-deny) 데모
# 망연계 게이트웨이의 핵심 개념(기본 차단 + 명시적 허용만 통과)을
# Docker 네트워크 2개로 단일 VM에서 시연한다.
# 실행: bash 06_netseg_demo.sh   (docker 필요)
set -uo pipefail

echo "=== 망분리 · default-deny 데모 ==="

echo "[1] 두 세그먼트(망) 생성"
docker network create seg_a >/dev/null
docker network create seg_b >/dev/null

echo "[2] 각 망에 컨테이너 배치"
docker run -d --name host_a --network seg_a alpine sleep 3600 >/dev/null
docker run -d --name host_b --network seg_b alpine sleep 3600 >/dev/null
B_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' host_b)
echo "    host_b IP: $B_IP"

echo "[3] default-deny 확인 — seg_a → seg_b 접근 시도 (다른 망이라 차단 기대)"
docker exec host_a sh -c "ping -c1 -W2 $B_IP >/dev/null 2>&1 && echo '    연결됨 (차단 실패)' || echo '    >> 망 간 차단됨 (default-deny)'"

echo "[4] 명시적 허용 — host_a를 seg_b에도 연결(화이트리스트) 후 재시도"
docker network connect seg_b host_a
docker exec host_a sh -c "ping -c1 -W2 $B_IP >/dev/null 2>&1 && echo '    >> 명시적 허용 후 통과 (allow-list)' || echo '    실패'"

echo "[5] 정리"
docker rm -f host_a host_b >/dev/null
docker network rm seg_a seg_b >/dev/null

echo
echo "결과 해석: 기본은 망 간 차단(default-deny), 명시적으로 허용한 경로만 통과 —"
echo "망연계 게이트웨이의 핵심 원리(허용된 신호만 오간다)를 단일 VM에서 시연."

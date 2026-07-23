#!/usr/bin/env bash
# 05_vuln_scan.sh - Trivy 취약점 스캔 (조치 절차 시연: 스캔 -> CVSS -> 패치 -> 재스캔)
# 실행: sudo bash 05_vuln_scan.sh
set -uo pipefail

echo "==> Trivy 설치"
if ! command -v trivy >/dev/null 2>&1; then
cat > /etc/yum.repos.d/trivy.repo <<'EOF'
[trivy]
name=Trivy repository
baseurl=https://get.trivy.dev/rpm/releases/$basearch/
gpgcheck=0
enabled=1
EOF
  dnf install -y trivy >/dev/null 2>&1 || true
fi
command -v trivy >/dev/null 2>&1 || { echo "trivy 설치 실패. https://trivy.dev/latest/getting-started/installation/ 참고"; exit 1; }

echo
echo "==> [1] 취약점 스캔 — 컨테이너 이미지 예시 (CVSS 심각도 정렬)"
echo "    구버전 베이스 이미지를 일부러 스캔해 취약점을 노출시킵니다."
trivy image --severity HIGH,CRITICAL --scanners vuln python:3.9-slim 2>/dev/null | head -40

echo
echo "==> [2] 위험도 평가 → 우선순위 (위 목록의 CRITICAL 부터 조치)"
echo "==> [3] 패치 후 재스캔 — 최신 베이스로 교체 시 취약점 감소 확인"
echo "    trivy image --severity HIGH,CRITICAL --scanners vuln python:3.12-slim | head -40"
echo
echo "==> (선택) 이 VM 자체의 OS 패키지 CVE 스캔:"
echo "    sudo trivy rootfs --severity HIGH,CRITICAL / | head -40"
echo "    sudo dnf update -y   # 패치 적용 후"
echo "    sudo trivy rootfs --severity HIGH,CRITICAL / | head -40   # 재스캔"
echo
echo "이 스캔→평가→패치→재스캔 흐름이 곧 '취약점 조치 절차(순환)' 슬라이드의 실물 증거입니다."

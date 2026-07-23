#!/usr/bin/env bash
# 03_fim_aide.sh - AIDE 파일 무결성 감시 시연
# 실행: sudo bash 03_fim_aide.sh
set -uo pipefail

echo "==> AIDE 설치"
dnf install -y aide >/dev/null 2>&1 || true

# 모델 파일 보호 대상 추가 (AI 인프라 특화 데모)
mkdir -p /opt/models
echo "FAKE-MODEL-WEIGHTS-v1" > /opt/models/model.bin
grep -q '/opt/models' /etc/aide.conf 2>/dev/null || echo "/opt/models NORMAL" >> /etc/aide.conf

echo "==> 기준(baseline) DB 생성 ... (수 분 소요될 수 있음)"
aide --init
cp -f /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz 2>/dev/null || true
echo "  baseline 생성 완료."

echo
echo "==> [시뮬레이션] 공격자가 설정 파일과 모델 파일을 변조합니다."
echo "# tampered by demo $(date)" >> /etc/hosts
echo "BACKDOOR" >> /opt/models/model.bin
echo "  /etc/hosts, /opt/models/model.bin 변조함."

echo
echo "==> 무결성 검사 실행 (변조 탐지 기대):"
aide --check || true
echo
echo "위 결과에 'changed: /etc/hosts', '/opt/models/model.bin' 이 뜨면 탐지 성공입니다."

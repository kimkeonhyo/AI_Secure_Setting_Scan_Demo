#!/usr/bin/env bash
# 02_openscap.sh - OpenSCAP CIS 준수 스캔 (하드닝 전/후 비교)
# 실행: sudo bash 02_openscap.sh before   /   sudo bash 02_openscap.sh after
set -uo pipefail
MODE="${1:-before}"

echo "==> OpenSCAP 설치"
dnf install -y openscap-scanner scap-security-guide >/dev/null 2>&1 || true

# Rocky(rl9) / RHEL(rhel9) 데이터스트림 자동 탐색
DS=$(find /usr/share -name 'ssg-*rl9*-ds.xml' 2>/dev/null | head -1)
[ -z "$DS" ] && DS=$(find /usr/share -name 'ssg-*rhel9*-ds.xml' 2>/dev/null | head -1)
if [ -z "$DS" ]; then echo "SCAP 데이터스트림을 못 찾았습니다. 'rpm -ql scap-security-guide | grep ds.xml' 로 확인하세요."; exit 1; fi
echo "  datastream: $DS"

# CIS 프로파일(환경에 따라 id가 다를 수 있어 자동 선택 + 출력)
echo "==> 사용 가능한 프로파일:"
oscap info "$DS" 2>/dev/null | grep -iE 'profile' || true
PROFILE="${PROFILE:-$(oscap info "$DS" 2>/dev/null | grep -oE 'xccdf_org.ssgproject.content_profile_cis[a-z0-9_]*' | head -1)}"
[ -z "$PROFILE" ] && PROFILE="xccdf_org.ssgproject.content_profile_cis"
echo "  선택 프로파일: $PROFILE  (바꾸려면 PROFILE=... 로 재실행)"

echo "==> 스캔 실행 ($MODE) ..."
oscap xccdf eval \
  --profile "$PROFILE" \
  --results "scan-$MODE.xml" \
  --report  "report-$MODE.html" \
  "$DS" || true

echo
echo "리포트 생성됨: report-$MODE.html"
echo "브라우저로 열어 상단의 '준수 점수(pass %)'를 확인하세요."
echo "before/after 두 리포트의 점수 차이가 하드닝 효과의 증거가 됩니다."

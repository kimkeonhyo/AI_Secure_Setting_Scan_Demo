#!/usr/bin/env bash
# 04_falco.sh - Falco 런타임 이상 탐지 설치 및 커스텀 룰
# 실행: sudo bash 04_falco.sh
set -uo pipefail

echo "==> Falco 저장소 등록 및 설치"
rpm --import https://falco.org/repo/falcosecurity-packages.asc 2>/dev/null || true
curl -s -o /etc/yum.repos.d/falcosecurity.repo https://falco.org/repo/falcosecurity-rpm.repo
dnf install -y falco >/dev/null 2>&1 || dnf install -y falco

echo "==> AI 인프라 특화 커스텀 룰 추가"
mkdir -p /etc/falco/rules.d
cat > /etc/falco/rules.d/poc.yaml <<'EOF'
- rule: 모델 파일 비인가 접근
  desc: 허용되지 않은 프로세스가 모델 가중치 파일을 읽음
  condition: >
    open_read and fd.name startswith /opt/models
    and not proc.name in (python, python3, inference)
  output: "모델 파일 비인가 접근 (user=%user.name proc=%proc.name file=%fd.name)"
  priority: WARNING
  tags: [ai, exfiltration]

- rule: 의심 네트워크/마이닝 도구 실행
  desc: nc/ncat/암호화폐 채굴 도구 등 실행 탐지
  condition: spawned_process and proc.name in (nc, ncat, xmrig, minerd)
  output: "의심 프로세스 실행 (cmd=%proc.cmdline user=%user.name)"
  priority: WARNING
  tags: [mining, network]
EOF

echo
echo "==> 데모 방법 (터미널 2개 사용)"
echo "  [터미널 A] 감시 시작 (60초):"
echo "      sudo falco -M 60"
echo "      * 커널 드라이버 오류 시:  sudo falco -o engine.kind=modern_ebpf -M 60"
echo
echo "  [터미널 B] 공격 시뮬레이션(아무 계정이나):"
echo "      sudo -u nobody cat /opt/models/model.bin    # 모델 파일 비인가 접근"
echo "      ncat -h                                       # 의심 도구 실행"
echo
echo "  터미널 A에 WARNING 알림이 뜨면 탐지 성공입니다."

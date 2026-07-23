#!/usr/bin/env bash
# 01_harden.sh - Rocky Linux 9 기본 하드닝 (PoC 데모용)
# 실행: sudo bash 01_harden.sh
# 주의: 일회용 실습 VM에서만 실행하세요. SSH/서비스 설정을 변경합니다.
set -uo pipefail

echo "==> [1/8] SELinux enforcing 전환"
setenforce 1 2>/dev/null || true
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config

echo "==> [2/8] 불필요 서비스 비활성화 (있을 때만)"
for svc in cups avahi-daemon rpcbind; do
  systemctl disable --now "$svc" 2>/dev/null && echo "  disabled $svc" || true
done

echo "==> [3/8] 호스트 방화벽 default-deny (SSH·HTTPS만 허용)"
dnf install -y firewalld >/dev/null 2>&1 || true
systemctl enable --now firewalld
firewall-cmd --set-default-zone=drop >/dev/null
firewall-cmd --permanent --zone=drop --add-service=ssh   >/dev/null
firewall-cmd --permanent --zone=drop --add-port=443/tcp  >/dev/null
firewall-cmd --reload >/dev/null

echo "==> [4/8] SSH 하드닝 (root 로그인 차단·인증 제한)"
SSHD=/etc/ssh/sshd_config
cp "$SSHD" "${SSHD}.bak.$(date +%s)"
sed -i \
  -e 's/^#\?PermitRootLogin.*/PermitRootLogin no/' \
  -e 's/^#\?MaxAuthTries.*/MaxAuthTries 3/' \
  -e 's/^#\?LoginGraceTime.*/LoginGraceTime 30/' \
  -e 's/^#\?X11Forwarding.*/X11Forwarding no/' \
  -e 's/^#\?ClientAliveInterval.*/ClientAliveInterval 300/' \
  "$SSHD"
# 키 기반 인증 강제는 데모 시 잠금 위험이 있어 주석으로 남깁니다(키 등록 후 활성화 권장):
# sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD"
sshd -t && systemctl restart sshd && echo "  sshd 재시작 완료"

echo "==> [5/8] 커널 파라미터 하드닝"
cat > /etc/sysctl.d/99-hardening.conf <<'EOF'
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_syncookies = 1
EOF
sysctl --system >/dev/null

echo "==> [6/8] 비밀번호 정책 강화"
sed -i 's/^# minlen.*/minlen = 12/;  s/^# dcredit.*/dcredit = -1/; s/^# ucredit.*/ucredit = -1/; s/^# lcredit.*/lcredit = -1/; s/^# ocredit.*/ocredit = -1/' /etc/security/pwquality.conf 2>/dev/null || true
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/; s/^PASS_MIN_LEN.*/PASS_MIN_LEN 12/' /etc/login.defs 2>/dev/null || true

echo "==> [7/8] auditd 감사 로깅"
dnf install -y audit >/dev/null 2>&1 || true
systemctl enable --now auditd
cat > /etc/audit/rules.d/hardening.rules <<'EOF'
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k scope
-w /var/log/sudo.log -p wa -k actions
-a always,exit -F arch=b64 -S execve -F euid=0 -k rootcmd
EOF
augenrules --load 2>/dev/null || service auditd restart 2>/dev/null || true

echo "==> [8/8] sudo 명령 로깅"
echo 'Defaults logfile="/var/log/sudo.log"' > /etc/sudoers.d/10-logging
chmod 440 /etc/sudoers.d/10-logging

echo
echo "완료. SELinux 라벨/enforcing 완전 반영을 위해 재부팅을 권장합니다:  sudo reboot"

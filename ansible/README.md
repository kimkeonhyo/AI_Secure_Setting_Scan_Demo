# Ansible 자동화 — AI 서버(OS) 보안 하드닝 · 컴플라이언스 스캔

단일 VM 바시 스크립트(`01_harden.sh` ~ `06_netseg_demo.sh`)로 수행한 실증(D1~D6)을
**Ansible 롤 기반으로 재구성**한 것입니다. bash와 달리 **멱등(idempotent)** 하게 동작하며,
한 명령으로 하드닝스캔 전체를 재현합니다.

## 디렉터리 구조 (표준 롤 기반)

```
ansible/
├── ansible.cfg
├── requirements.yml          # ansible.posix, community.general
├── inventory/hosts.ini
├── group_vars/all.yml
├── site.yml                  # 진입점 (hardening -> tools -> scan)
└── roles/
    ├── hardening/            # D1  OS 하드닝 (sysctl/SELinux/SSH/auditd)
    ├── security_tools/      # D2 AIDE · D3 Falco · D5 Trivy · D6 docker
    └── compliance_scan/     # D1 OpenSCAP 평가 + Ansible 조치 자동생성, D5 Trivy
```

## 사전 준비

```bash
ansible-galaxy collection install -r requirements.yml
```

## 실행

```bash
cd ansible
ansible-playbook site.yml                 # 전체
ansible-playbook site.yml --tags hardening # 하드닝만
ansible-playbook site.yml --tags scan      # 스캔만
ansible-playbook site.yml --check          # dry-run (변경 없이 차이만 확인)
```

## 데모(D1~D6) · 발표 자료 매핑

| 롤 | 작업 | 데모 |
|------|------|------|
| `hardening` | sysctl(ASLR/네트워크), SELinux enforcing, SSH, auditd, /dev/shm | D1 |
| `security_tools` | AIDE, Falco, Trivy, docker 설치/구성 | D2/D3/D5/D6 |
| `compliance_scan` | OpenSCAP CIS 평가 + **Ansible 조치 playbook 자동생성**, Trivy 스캔 | D1/D5 |

## 핵심 — OpenSCAP → Ansible 자동 조치

`compliance_scan` 롤은 OpenSCAP 평가 후 **조치 playbook을 Ansible 형식으로 자동 생성**합니다:

```bash
oscap xccdf generate fix --fix-type ansible \
  --profile xccdf_org.ssgproject.content_profile_cis \
  --output oscap-remediation.yml  ssg-rl9-ds.xml
```

즉 **스캔 → 조치 playbook 생성 → 멱등 배포**로 이어지는 취약점 조치 순환 절차(발표 4p)를
실제 코드로 구현한 것입니다.

## 참고

- 본 playbook은 멱등적으로 안전한 OS 레벨 하드닝/스캔을 다룹니다.
- Verified Boot · Full Disk Encryption · 커널 모듈 서명/lockdown 등 **부팅/하드웨어 레벨 항목**은
  골든 이미지 · 부트 구성 단계에서 적용되며 본 데모의 범위 밖입니다.
- 대상 OS: Rocky Linux 8/9 (RHEL 계열). datastream 경로는 `group_vars/all.yml`에서 조정.

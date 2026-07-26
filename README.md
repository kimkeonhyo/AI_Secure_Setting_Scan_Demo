# AI 서버 보안 아키텍처 — 단일 VM PoC (코어 데모)

발표 결론용으로, 앞의 레퍼런스 아키텍처의 **핵심 통제**를 Rocky Linux 9 VM 한 대에서 실제로 시연하는 키트입니다.
"이렇게 하겠다"가 아니라 **"공격 시도 → 차단·탐지되는 화면"**을 직접 보여주는 것이 목표입니다.

## 무엇을 증명하나 (아키텍처 ↔ 데모 매핑)

| 아키텍처 요소 | 이 PoC에서 시연 | 스크립트 |
|---|---|---|
| OS 하드닝 (SELinux·CIS) | OpenSCAP CIS 스캔 — 하드닝 전/후 점수 비교 | `01_harden.sh`, `02_openscap.sh` |
| 파일 무결성 감시 (FIM) | AIDE로 설정 파일 변조 실시간 탐지 | `03_fim_aide.sh` |
| 런타임 이상 탐지 (EDR) | Falco로 비인가 프로세스·모델 파일 접근 탐지 | `04_falco.sh` |
| AI Gateway (인증된 요청만 통과) | TLS 1.3 + 토큰 인증 + rate limit + 프롬프트 필터 | `gateway/` |
| 망분리(논리) + egress 제한 | Docker 내부망(inference 외부 노출 없음) | `gateway/docker-compose.yml` |
| 취약점 조치 절차 | Trivy 스캔 → CVSS 정렬 → 패치 → 재스캔 | `05_vuln_scan.sh` |
| 망분리 default-deny (망연계 원리) | Docker 망 2개 — 기본 차단 + 명시적 허용만 통과 | `06_netseg_demo.sh` |

## 사전 준비

### 옵션 A — VirtualBox 로컬 VM (Win11 Home 호환)
1. VirtualBox 설치 → Rocky Linux 9 ISO(rockylinux.org)로 새 VM 생성 (2 vCPU / 4GB RAM / 30GB).
2. 설치 시 "Minimal Install" 선택, 사용자 계정 하나 생성(sudo 권한).
3. VM 부팅 후 이 `poc/` 폴더를 통째로 VM으로 복사 (공유폴더 또는 `scp`).

### 옵션 B — 클라우드 VM (AWS/Azure 프리티어)
1. Rocky Linux 9 이미지로 인스턴스 생성 (t3.small / B1s 급, 2GB 이상 권장).
2. 보안그룹/방화벽: **본인 IP에서만** 22(SSH), 443(HTTPS) 허용.
3. `scp -r poc/ user@서버:~/` 로 복사 후 SSH 접속.

> ⚠️ 두 옵션 모두 **일회용 실습 VM**에서 실행하세요. `01_harden.sh`는 SSH·서비스 설정을 바꾸므로 업무용 서버에 절대 실행 금지.

### 공통 — Docker 설치 (게이트웨이용)
```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker
```

## 실행 순서

```bash
# 0) (권장) 하드닝 전 기준 점수 측정
sudo bash 02_openscap.sh before

# 1) OS 하드닝 적용  (완료 후 SELinux 반영 위해 재부팅 권장)
sudo bash 01_harden.sh
sudo reboot

# 2) 하드닝 후 점수 재측정 → report-before.html vs report-after.html 비교
sudo bash 02_openscap.sh after

# 3) 파일 무결성 감시 시연
sudo bash 03_fim_aide.sh

# 4) 런타임 이상 탐지 시연 (안내 따라 2개 터미널 사용)
sudo bash 04_falco.sh

# 5) AI Gateway 기동
cd gateway && bash gen_certs.sh && sudo docker compose up -d --build && cd ..

# 6) 취약점 조치 절차 시연
sudo bash 05_vuln_scan.sh

# 7) 망분리(default-deny) 시연 — 세그먼트 간 기본 차단 → 명시적 허용만 통과
bash 06_netseg_demo.sh
```

시연 대본과 캡처 포인트는 [DEMO.md](DEMO.md) 참고.

## 주의
- 스크립트는 Rocky Linux 9 기준으로 작성했고 이 환경에서 실제 실행 검증은 하지 못했습니다. VM에서 돌리다 막히는 부분은 알려주시면 바로잡겠습니다.
- Ubuntu에서 돌리려면 패키지명(dnf→apt), SELinux→AppArmor, OpenSCAP 콘텐츠 경로가 달라집니다. 필요하면 Ubuntu 버전도 만들어 드릴게요.

# OMX 임피던스·텔레오퍼레이션 PC Ansible 셋업

`교육/창원교육/new_OMX/OMX-이관-통합가이드.md` 의 ②~⑥을 자동화하고,
**실물 검증까지 마친**(2026-11-18, pink) 플레이북 모음.

빈 우분투 노트북을 다음이 전부 되는 상태로 만든다:

- **HTML 제어 패널** — 중력보상·임피던스 체험(리더), 관절제어·MoveJ/MoveL(팔로워)
- **텔레오퍼레이션** — 리더를 손으로 움직이면 팔로워가 실시간으로 따라옴 (`run_teleop.sh`)

스타일·인벤토리 규칙은 `교육/Mujoco+ROS2/pinklab-ansible/` 과 동일
(계정명 = 호스트명, 주소 = `호스트명.local`).

> 표기: 💻 = 제어 컴퓨터에서 실행 / 🖥️ = 새 PC(로봇 연결되는 쪽)에서 실행

---

## 소스의 원천 (중요)

| 무엇 | 어디서 가져오나 |
|---|---|
| `open_manipulator` (임피던스 패키지 포함) | 제어 컴퓨터의 `~/open_manipulator` — 검증된 원본 |
| 웹 제어 패널·임피던스 패키지·patch | 이 저장소의 `vendor/` (저장소만 받아도 자급자족) |

`om_impedance_controller` 는 **로보티즈 git에 없는 패키지**라 업스트림 clone으로는 못 받는다.
`~/open_manipulator` 가 없는 컴퓨터에서는 **`prepare_source.yml`** 이
업스트림 clone(커밋 고정) + `vendor/upstream-to-current.patch` + `vendor/om_impedance_controller` 로
검증된 원본을 재조립해 준다. 원본을 고치면 `source.yml` 재실행으로 전파.

## 파일 구성

| 파일 | 역할 |
|---|---|
| `site.yml` | 전체 셋업 (아래 5개를 순서대로) |
| `docker.yml` | 가이드 ② — 도커 설치 |
| `source.yml` | 가이드 ③ — 소스 rsync + 패널 + 실행 스크립트 배포 |
| `container.yml` | 가이드 ④ — udev + 이미지 pull + 컨테이너 기동 |
| `build.yml` | 가이드 ⑥ — rosbridge·python3-serial 설치 + 임피던스 빌드 |
| `verify.yml` | 부록 B — 로봇 없이 가능한 정적 검증 |
| `ping.yml` | 연결·sudo 확인만 |
| `prepare_source.yml` | `~/open_manipulator` 가 없는 컴퓨터에서 원본 재조립 (업스트림+vendor) |
| `make_usb.sh` | USB 배포 번들 생성 |
| `vendor/` | 임피던스 패키지 + patch + 제어 패널 (저장소 자급자족용) |
| `host_vars/<호스트>.yml` | **로봇 개체별** 리더/팔로워 by-id 포트 |

배포되는 실행 스크립트 (새 PC의 `~/omx/`):

| 스크립트 | 용도 |
|---|---|
| `scan_arms.sh` | 리더/팔로워 자동 식별 (읽기 전용 모터 스캔) |
| `run_teleop.sh` | **텔레오퍼레이션** (팔로워+리더, 안내 따라 Enter 2번) |
| `run_leader.sh` | 리더만 (패널 "임피던스·중력보상" 탭용) |
| `run_follower.sh` | 팔로워만 (패널 "관절제어"·"MoveJ/MoveL" 탭용) |
| `run_rosbridge.sh` | 패널 연결용 웹소켓 (텔레옵에는 불필요) |
| `OMX-Control.html` | 웹 제어 패널 (브라우저로 열기, https 금지) |

모든 run 스크립트는 **zenohd 자동 기동, ROS 환경변수, 임피던스 재스폰 워치독**을 내장한다.

---

# 1부. 설치 (새 PC 셋업)

## 1-0. 🖥️ 새 PC 사전 준비 (여기만 새 PC에서 직접)

우분투 24.04 설치 후:

```bash
sudo apt update && sudo apt install -y openssh-server
sudo systemctl enable --now ssh
echo "$(whoami) ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$(whoami)
hostname    # 이름 확인 (계정명=호스트명 규칙 권장)
```

## 1-1. 💻 SSH 키 등록 (새 PC 비밀번호 1회)

```bash
ssh-copy-id <계정>@<호스트명>.local
```

## 1-2. 💻 venv 준비 (처음 한 번)

```bash
cd ~/Documents/개발/omx-ansible
python3 -m venv .venv
.venv/bin/pip install ansible     # ansible-core 아님 — ansible.posix(synchronize) 필요
```

> venv는 절대경로가 박히므로 폴더를 옮기면 재생성.

## 1-3. 💻 인벤토리에 추가 + 연결 확인

`inventory.ini` 의 `[omx]` 아래에 호스트명 한 줄 추가 후:

```bash
.venv/bin/ansible-playbook ping.yml
```

## 1-4. 💻 전체 셋업 실행

```bash
.venv/bin/ansible-playbook site.yml --limit <호스트명>
```

- 이미지 pull이 수 GB — **수업 전날 미리** 돌려둘 것.
- 끝에 verify가 "✅ 검증 통과"를 찍으면 소프트웨어 셋업 완료.
- 전부 멱등: 실패하면 그냥 다시 실행. 컨테이너가 날아갔으면 `container.yml`+`build.yml`만 재실행.

## 1-5. 🖥️ 로봇 연결 + 포트 식별 ★로봇 개체마다 필수★

1. 리더·팔로워 USB를 새 PC에 연결
2. **팔로워 전원 어댑터 연결 + 스위치 ON** (팔로워는 외부 전원 필수! 리더는 USB만으로 됨)
3. 식별 스캔:

```bash
~/omx/scan_arms.sh
```

모터 ID로 자동 판별된다 — **ID 1~6 = 리더, ID 11~16 = 팔로워.**
"모터 무응답"이 나오면 그 암의 전원부터 확인.

## 1-6. 💻 host_vars 작성 + 재배포

스캔이 알려준 by-id 경로를 `host_vars/<호스트명>.yml` 에 기록 (pink.yml 참고):

```yaml
omx_leader_port: /dev/serial/by-id/usb-ROBOTIS_OpenRB-150_<리더시리얼>-if00
omx_follower_port: /dev/serial/by-id/usb-ROBOTIS_OpenRB-150_<팔로워시리얼>-if00
omx_port_name: "{{ omx_leader_port }}"
```

```bash
.venv/bin/ansible-playbook source.yml --limit <호스트명>   # 포트 반영 재배포
```

> by-id 로 고정하는 이유: `/dev/ttyACM0/1` 번호는 **꽂는 순서에 따라 뒤바뀐다** (실제로 겪음).

## 1-α. 제어 컴퓨터 없이 새 PC 혼자서 할 때 (git 또는 USB로 받은 경우)

이 저장소를 **git clone 또는 USB**로 새 PC에 가져왔다면, 🖥️ 새 PC에서 전 과정을 진행한다:

```bash
cd ~/omx-ansible                                   # 받은 폴더
python3 -m venv .venv && .venv/bin/pip install ansible

# 원본 open_manipulator 가 없으면 재조립 (인터넷 필요 · USB에 open_manipulator/ 가
# 같이 있으면 ~/open_manipulator 로 복사하는 걸로 대체 가능)
.venv/bin/ansible-playbook prepare_source.yml
```

`inventory.ini` 의 `[omx]` 에 자기 자신을 추가 — 아래 한 줄을 복사해 실행하면
내 계정명(`whoami`)이 자동으로 채워진다:

```bash
sed -i "/^\[omx\]/a myself ansible_host=localhost ansible_connection=local ansible_user=$(whoami)" inventory.ini
```

(직접 편집한다면 `ansible_user=` 뒤에 본인 리눅스 계정명 — `whoami` 로 확인 — 을 적으면 된다)

```ini
[omx]
myself ansible_host=localhost ansible_connection=local ansible_user=pink   # 예: 계정이 pink인 PC
```

이후 **1-4 → 1-5 → 1-6 을 똑같이** 진행하면 된다 (💻 표시 단계도 전부 새 PC에서 하는 것만 다름).
1-0의 SSH 서버·ssh-copy-id 는 localhost 방식에서는 불필요.

---

# 1.5부. 다른 사람에게 전달하기 (배포)

**방법 A — git**: 공개 저장소 https://github.com/ssseohyeon/omx-ansible

```bash
git clone https://github.com/ssseohyeon/omx-ansible.git ~/omx-ansible
```

→ 위 1-α 순서. `vendor/` + `prepare_source.yml` 덕에 이 저장소만으로 자급자족.

**방법 B — USB**:

```bash
./make_usb.sh /media/$USER/<USB라벨>
```

omx-ansible(+ 있으면 open_manipulator 원본까지)를 USB에 담는다.
받는 사람: USB의 두 폴더를 홈에 복사 → 위 1-α 순서 (원본이 USB에 있으면 인터넷 불필요).

---

# 2부. 실행 (전부 🖥️ 새 PC에서, 이 순서대로)

> **공통 안전 수칙**
> - 리더 launch가 뜨는 순간 토크가 들어간다 — **리더는 항상 사람이 잡고 시작**
> - 로봇 옆에 사람이 있는 상태에서만 실행. 무인·원격 단독 실행 금지
> - 설치 직후라면 **로그아웃→로그인(또는 재부팅) 한 번** — 안 하면 docker 권한 오류 (아래 트러블슈팅 1번)

## 2-A. 텔레오퍼레이션

```bash
~/omx/run_teleop.sh
```

스크립트가 차례대로 안내한다:

1. 체크리스트 확인 → Enter — 팔로워 전원 ON? **두 팔을 손으로 비슷한 자세로 맞췄나?**
   (자세 차이가 크면 시작 순간 팔로워가 크게 점프함)
2. `[1/2] 팔로워 기동` — 현재 자세를 유지한 채 대기 (자동 검증 포함)
3. `[2/2] 리더 팔을 잡고 Enter` — **누르는 순간 미러링 시작.** 리더를 움직이면 팔로워가 따라옴
4. 종료: Ctrl+C (리더 받치면서) — 팔로워는 자동 정리됨

> ⚠ 업스트림 `omx_ai.launch.py` 의 "초기 자세 이동"(전 관절 0도) 단계는 **일부러 뺐다.**
> 우리 팔로워 개체에서 허용 범위를 넘어 과부하 에러(빨간불)를 냈기 때문 (트러블슈팅 7번).
> 대신 사람이 두 팔 자세를 맞추고 시작한다.

## 2-B. HTML 패널 — 중력보상·임피던스 (리더)

```bash
# 터미널 1 — ⚠ 리더 팔 잡고
~/omx/run_leader.sh
# 터미널 2
~/omx/run_rosbridge.sh
```

브라우저로 `~/omx/OMX-Control.html` 열기(더블클릭) → 주소창 `ws://localhost:9090` → 연결.

- **"리더암 — 임피던스·중력보상" 탭**: 켠 직후가 중력보상(K=0).
  **set_reference 먼저** → damping 0.5 → stiffness 1부터 조금씩 (상한 30 클램프).
  이상하면 stiffness 0 → 즉시 중력보상 복귀.

## 2-C. HTML 패널 — 관절제어·MoveJ/MoveL (팔로워)

```bash
# 터미널 1 (팔로워 전원 ON 확인)
~/omx/run_follower.sh
# 터미널 2
~/omx/run_rosbridge.sh
```

패널의 "관절 조작"(슬라이더·3D 드래그), "MoveJ/MoveL" 탭 사용.

> 2-A/B/C 는 동시에 섞지 말 것 — 전환할 때는 기존 launch를 Ctrl+C 로 끄고 다음 것을 실행.
> (리더+팔로워 단독 launch 조합은 공존 가능하지만, 텔레옵 전환 시에는 둘 다 끄고 run_teleop.sh)

---

# 3부. 트러블슈팅 — 전부 실제로 겪은 오류다 (2026-11-18, pink)

| # | 증상 | 원인 | 해결 |
|---|---|---|---|
| 1 | `permission denied ... docker.sock` | 설치 때 docker 그룹에 넣었지만 **GUI 로그인 세션이 그 전에 시작**됨 — 그 세션의 모든 터미널에 미반영 | 로그아웃→로그인(또는 재부팅). 급하면 터미널마다 `newgrp docker` |
| 2 | 스크립트 실행해도 컨테이너에 아무 일 없음 | = 1번. docker 명령이 첫 줄에서 죽은 것 | 위와 동일 |
| 3 | 리더·팔로워 포트가 뒤바뀜 | `/dev/ttyACM0/1` 은 **꽂는 순서대로 열거**됨 — USB 다시 꽂으면 번호가 바뀜 | by-id 경로로 고정 (`host_vars`), `scan_arms.sh` 로 식별 |
| 4 | 팔로워 모터 전체 무응답 (보드는 USB로 잡힘) | **팔로워 전원 어댑터 미연결/스위치 OFF** — 보드는 USB 전원으로 살아있어 착각하기 쉬움 | 어댑터·스위치 확인. 전원 들어오면 관절 LED가 잠깐 깜빡임. `scan_arms.sh` 로 확인 |
| 5 | 노드들이 서로를 못 찾음 / `Unable to connect to a Zenoh router` | 이 컨테이너는 **zenoh RMW** (`ROS_DOMAIN_ID=30`) — zenohd(교환원)가 없으면 통신 불가 | run 스크립트가 자동 기동함. 수동이면 `ros2 run rmw_zenoh_cpp rmw_zenohd` 를 먼저, 계속 켜둠 |
| 6 | 리더가 유난히 무거움 (중력보상 없음) | launch 의 **임피던스 스포너가 조용히 실패**하는 경우가 있음 — effort 인터페이스가 unclaimed 로 남음 | run 스크립트의 워치독이 25초 후 자동 재스폰. 수동: `ros2 run controller_manager spawner impedance_controller -c /leader/controller_manager` |
| 7 | 텔레옵 시작 중 팔로워가 이상한 자세에서 멈추고 **모터 빨간불**이 계속 깜빡임 | 업스트림 초기자세 이동(step1=전 관절 0도)이 **이 팔로워의 허용 범위를 초과** → 과부하 하드웨어 에러 + executor 무한 대기 | ① 토크 명령 중단(launch 종료) ② **팔로워 전원 껐다 켜기** (빨간불은 전원 리셋으로만 해제) ③ `run_teleop.sh` 는 이 단계를 생략하도록 이미 수정됨 |
| 8 | 텔레옵이 `[2/3]` 단계에서 멈춰서 리더가 안 뜸 (구버전 스크립트) | 7번과 같음 — executor 가 도달 불가능한 목표를 영원히 대기 | 현재 스크립트는 executor 없음. 혹시 멈추면 Ctrl+C 후 재실행 |
| 9 | `ros2 control list_controller_types` 가 응답 없음 (통합가이드 ⑥-4) | 이 명령은 **launch(controller_manager)가 떠 있어야만** 동작 — 가이드 설명과 다름 | 로봇 없는 검증은 `verify.yml` 의 정적 검사(.so·pluginlib 인덱스·클래스명)로 대체됨 |
| 10 | launch를 pkill 해도 arm이 계속 잡혀 있음 | launch 부모만 죽고 **자식(ros2_control_node 등)이 잔존** | `pkill -f "config/omx_f"` 처럼 config 경로로 죽일 것. run_teleop.sh 종료 trap에 반영됨 |
| 11 | `scan_arms.sh` 에서 `No module named 'serial'` | 컨테이너에 python3-serial 없음 (dynamixel_sdk 의존성) | `build.yml` 이 설치함 — 재실행: `ansible-playbook build.yml --limit <호스트>` |
| 12 | `pink.local` 등 `.local` 주소가 간헐적으로 안 풀림 | mDNS 일시 장애 | 잠시 후 재시도. 계속되면 inventory에 `ansible_host=<IP>` 지정 |
| 13 | 재시작했더니 rosbridge·빌드가 사라짐 | `container.sh stop`/`compose down` 은 컨테이너를 **삭제**함 | **down 금지.** 재시작은 `docker restart open_manipulator`. 지워졌으면 `build.yml` 재실행으로 복구 |

## 로봇을 다른 개체로 바꿀 때 (통합가이드 부록 E)

- `scan_arms.sh` → `host_vars` 포트 갱신 → `source.yml` 재배포는 **필수**
- `torque_scaling_factors`·`Current Limit`·게인 상한은 소스에 박힌 튜닝값 — 개체가 다르면
  통합가이드 부록 E 대로 원본 `~/open_manipulator` 를 재튜닝 후 `source.yml` 재배포
- 초기자세 과부하(트러블슈팅 7)는 개체마다 다를 수 있음 — 새 팔로워에서 초기자세 이동을
  써보고 싶으면 반드시 손 닿는 거리에서 전원 스위치를 잡고 시험할 것

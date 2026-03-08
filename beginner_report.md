# [레포트] Jetson SOEM v2.0 라이브러리화 및 Qt 연동 가이드

본 문서는 초보 개발자가 Jetson 환경에서 SOEM v2.0 소스 코드를 공유 라이브러리(`.so`)로 만들고, 이를 Qt Creator에서 자유롭게 호출하여 사용하는 전 과정을 설명합니다.

---

## 🚀 [퀵 스타트] 딱 4단계로 셋업 끝내기

이 가이드를 따라 하시면 **윈도우 더블클릭 실행**만으로 젯슨에 필요한 개발 환경이 자동으로 만들어집니다.

1.  **[사전 확인]**: 
    - 젯슨 보드에 있는 원본 SOEM 폴더 이름이 반드시 **`j_soem_master`** 인지 확인하세요.
    - 윈도우 시작 메뉴에서 **'장치 관리자'**를 검색해 엽니다. `네트워크 어댑터` 아래에 **`Remote NDIS Compatible Device`**가 있는지 반드시 확인하세요.
2.  **[명령어 실행]**: 탐색기에서 프로젝트 폴더로 이동 후 `Deploy-SOEM.cmd` 파일을 바로 **더블클릭**합니다.
3.  **[원클릭 배포]**: 
    - 안내에 따라 젯슨의 아이디를 적습니다.
    - 비밀번호를 한 번 타이핑해주면, **이후부터는 자동 로그인/권한 설정 키 교환이 이루어져** 번거로움 없이 끝까지 쭈욱 자동 배포가 진행됩니다. (키 인증을 위해 최초 한 번만 터미널이 한 번 더 묻습니다)
4.  **[바로 코딩 시작]**: 잠시 후 젯슨 화면에 **Qt Creator가 프로젝트와 함께 자동으로 나타납니다!**

---

## 1. 개요 및 구조
기존의 SOEM 샘플 코드는 소스 전체를 포함하여 빌드해야 하는 복잡함이 있습니다. 이를 해결하기 위해 **통신 핵심 로직을 라이브러리(`.so`)로 분리**하고, 사용자는 간단한 함수 호출만으로 EtherCAT 통신을 제어할 수 있도록 설계했습니다.

### 폴더 구조
*   `~/j_soem_master`: 원본 SOEM v2.0 소스 (읽기 전용)
*   `~/soem_lib_build`: 라이브러리 빌드 엔진 (Makefile, 래퍼 코드)
*   `~/jetson_ecat_engine`: 최종 Qt Creator 프로젝트 (엔진) **(보고서 및 가이드 파일이 이 안에 들어있습니다!)**

---

## 2. 자동화 구성 요소

### (1) 윈도우용 자동 배포 스크립트 (`Deploy-SOEM.cmd`)
이 스크립트는 윈도우에서 실행되며, Jetson의 IP, ID, 비밀번호를 물어본 뒤 필요한 모든 파일을 Jetson으로 전송하고 자동 설치를 시작합니다.

*   **사용법**: 윈도우 탐색기에서 `Deploy-SOEM.cmd` 파일을 더블클릭하여 실행합니다.
*   **기능**: SSH 정보 입력 가이드, 파일 전송, 원격 명령 실행 (인코딩/권한 문제 자동 우회)

### (2) Jetson용 재빌드 스크립트 (`rebuild_so.sh`)
라이브러리에 새로운 기능을 추가하거나 수정했을 때, 복잡한 명령어 없이 한 번에 반영해주는 도구입니다.

*   **위치**: `~/soem_lib_build/rebuild_so.sh`
*   **실행**: `./rebuild_so.sh ~/jetson_ecat_engine`
*   **효과**: 소스 재컴파일 -> `.so` 파일 생성 -> Qt 프로젝트로 자동 복사

### (3) 윈도우용 빠른 라이브러리 반영 스크립트 (`Lib_make_run.cmd` / `lib_make_run.ps1`)
Jetson의 `~/soem_lib_build/ec_sample.c`를 수정한 뒤, Windows에서 더블클릭으로 라이브러리를 재빌드하고 프로젝트로 동기화합니다.

*   **사용법**: `Lib_make_run.cmd` 더블클릭
*   **효과**: `libec_sample.so` 재생성 + `~/jetson_ecat_engine`로 `.so`/`.h` 동기화

### (4) 윈도우용 Qt 재시작 스크립트 (`Qt_run.cmd` / `Qt_run.ps1`)
현재 실행 중인 `jetson_ecat_engine` 프로젝트의 Qt Creator UI만 종료 후 다시 실행합니다.

*   **사용법**: `Qt_run.cmd` 더블클릭
*   **효과**: 다른 작업과 섞이지 않고 현재 프로젝트만 재시작

---

## 3. 핵심 사용법 (초보자용)

### 단계 1: Jetson에서 Qt Creator 실행 및 프로젝트 열기
가장 먼저 젯슨 바탕화면에서 Qt Creator를 켭니다.

**방법 A: 바탕화면 메뉴에서 켜기**
1. 젯슨 왼쪽 상단의 **메뉴 버튼**을 누릅니다.
2. `Programming` 카테고리에서 **Qt Creator**를 클릭합니다.

**방법 B: 터미널에서 켜기 (초보자 추천, 복사-붙여넣기)**
1. 터미널(검은 해커 창)을 엽니다. (키보드 단축키: `Ctrl` + `Alt` + `T`)
2. 아래 명령어를 그대로 복사해서 터미널에 붙여넣고 엔터를 누릅니다.
   ```bash
   qtcreator ~/jetson_ecat_engine/jetson_ecat_engine.pro &
   ```

**방법 C: 파일로 직접 열기**
1. 젯슨 파일 탐색기(Nautilus)를 엽니다.
2. `/home/pjy/jetson_ecat_engine` 폴더로 들어갑니다.
3. `jetson_ecat_engine.pro` 파일을 **더블 클릭**합니다.

## 3. 핵심 아키텍처 (ec_sample.c 라이브러리화)

기존에는 별도의 래퍼 라이브러리를 두었으나, 초보자에게 가장 친숙한 **`ec_sample.c` 자체를 공유 라이브러리(.so)로 만들었습니다.**
더불어 기존에 따로 놀던 `smart_auto_pdo_config`의 고급 자동 매핑 기능도 `ec_sample` 내부로 모두 통폐합시켰습니다.

### 💡 [중요] 타스커(OSAL Thread)를 삭제한 이유
원본 `ec_sample`에는 `osal_thread_create`를 이용해 통신을 주고받는 OSAL 타스크(스레드)가 들어 있습니다. 
하지만 이를 **Qt(GUI 프로그램)와 함께 쓰면 스레드 충돌이 발생하거나 제어권을 잃어 프로그램이 뻗어버리는 문제**가 발생합니다.
따라서 본 세팅에서는 타스크를 과감히 삭제하고, 대신 Qt의 안전한 타이머(`QTimer`) 함수가 주기적으로 `ecat_process_pdos()`를 호출하도록 아키텍처를 변경했습니다.

---

## 4. [초보자 실습] 라이브러리 코드 수정 및 Qt에서 제어하기

이제 `ec_sample.c` 파일 자체가 라이브러리의 원본입니다. 코드를 수정하고 Qt에 반영하는 과정은 다음과 같습니다.

### 1단계: 라이브러리(ec_sample.c) 직접 수정하기
터미널을 열고 코드를 수정합니다:
```bash
gedit ~/soem_lib_build/ec_sample.c &
```
여기서 `smart_auto_pdo_config()` 함수 내용이나, `ecatbringup()`, `ecat_process_pdos()` 내부 로직을 본인 하드웨어에 맞게 마음껏 뜯어고치세요!

### 2단계: 터미널에서 1초 만에 라이브러리 재빌드하기
코드 수정을 마쳤다면, 딱 한 줄 명령어로 `.so` 라이브러리를 굽고 Qt 프로젝트에 자동 배포합니다.
```bash
cd ~/soem_lib_build
./rebuild_so.sh ~/jetson_ecat_engine
```

### 3단계: Qt Creator에서 통신 돌리기 (`main.cpp`)
Qt 프로젝트에서는 더 이상 잡다한 설정 없이, 라이브러리에 뚫어놓은 직관적인 함수만 호출하면 됩니다.
```cpp
// main.cpp 예시
#include "ec_sample.h"

// 1. 통신 포트 열고, 슬레이브 찾고, OP 상태 진입!
if (ecatbringup("eno1")) {
    
    // 2. 주기적인 통신(송수신)을 타이머 등에서 호출
    ecat_process_pdos();
    ecat_check_status();
}

// 3. 끌 때는 안전하게 닫기
ecatbringdown();
```
(초록색 재생 버튼(▶)을 누르면 내부적으로 `sudo` 권한까지 알아서 획득하고 앱이 실행됩니다!)

---

## 5. Qt Creator 설정 설명 (자동화됨)
이미 자동화 스크립트가 세팅해 두었지만, 원리를 알면 좋습니다.
*   **INCLUDEPATH**: `test_lib.h` 같은 헤더 파일을 어디서 찾을지 지정합니다.
*   **LIBS**: `libjetson_soem.so` 라이브러리 파일을 링크(연결)합니다.
*   **QMAKE_LFLAGS (RPATH)**: 프로그램이 실행될 때 `.so` 파일이 어디 있는지 알려주는 경로 정보입니다.

## 5. 라이브러리 주요 API 목록

| 함수명 | 설명 |
| :--- | :--- |
| `smart_auto_pdo_config()` | PDO 자동 매핑 로직 수행 |
| `ecatbringup(ifname)` | 포트 오픈, 슬레이브 스캔, OP 진입 |
| `ecat_process_pdos()` | PDO 송수신 1주기 수행 |
| `ecat_check_status()` | 상태 점검 (타이머 주기 호출 권장) |
| `ecatbringdown()` | 통신 종료 및 자원 정리 |

---

## 6. 문제 해결 (Troubleshooting)

### (1) 인터페이스 초기화 실패 (Failed to initialize interface)
EtherCAT은 네트워크의 아주 깊은 곳(Raw Socket)을 제어하므로, **반드시 관리자 권한(root)**이 필요합니다. Qt Creator에서 그냥 실행하면 권한 부족으로 실패합니다.

**해결 방법 A: 터미널에서 관리자 모드로 실행 (초보자용 복붙 명령어)**
터미널 창(`Ctrl` + `Alt` + `T`)을 열고 아래 두 줄을 복사해서 붙여넣고 엔터를 치세요. (비밀번호를 물어보면 젯슨 비밀번호를 치면 됩니다.)
```bash
cd ~/jetson_ecat_engine
sudo ./jetson_ecat_engine
```

**해결 방법 B: Qt Creator에서 초록색 재생(Run) 버튼으로 바로 실행하기**
터미널에서 아래 긴 명령어를 **그대로 복사/붙여넣기** 해서 한 번만 실행해 두면, 이후부터는 Qt에서 버튼만 눌러도 됩니다.
```bash
sudo setcap 'cap_net_raw,cap_net_admin=eip' ~/jetson_ecat_engine/jetson_ecat_engine
```
*(주의: 소스 코드를 수정해서 파일을 다시 빌드/컴파일하면 이 권한 설정이 사라지므로 다시 해줘야 합니다.)*

---

### [참고] 라이브러리 수정 및 빌드 워크플로우
SOEM의 핵심 라이브러리 소스는 `~/soem_lib_build`에서 관리합니다. 여기서 코드를 수정하고 빌드하면 그 결과물이 프로젝트 폴더(`~/jetson_ecat_engine`)로 자동 전달되어 사용됩니다.

### [참고] 계정 입력/캐시 정책
`Deploy-SOEM.cmd`, `Lib_make_run.cmd`, `Qt_run.cmd`는 공통 자격증명 파일(`%USERPROFILE%\.qt_ecat_jetson_cred.xml`)을 사용합니다.

* 최초 1회: Jetson ID/비밀번호 입력 및 저장
* 이후 실행: 저장값 자동 재사용
* 다른 초보자 계정 사용 시: 실행 중 다른 ID를 입력하면 즉시 갱신 저장

**대상**: Jetson Power User & EtherCAT 초보자

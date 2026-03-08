---
description: 젯슨 원클릭 SOEM 통합 라이브러리 및 Qt 환경 자동 배포 프로세스
---
# SOEM (ec_sample) 자동 배포 시스템 워크플로우

이 워크플로우는 Windows 환경에서 Jetson 보드로 SOEM(`ec_sample.c`) 기반 공유 라이브러리를 만들고, Qt 프로젝트에 연동하여 빌드 및 권한 획득까지 전자동으로 수행하는 절차를 명세합니다.
향후 새로운 보드나 PC를 세팅할 때 별도의 스크립트 작성 없이 이 워크플로우만 실행하면 됩니다.
## 0. 현재 사용자 워크플로우 및 AI 에이전트 역할 (추가됨)

이 워크플로우는 Windows 환경에서 Jetson 보드로 SOEM(`ec_sample.c`) 기반 공유 라이브러리를 만들고, Qt 프로젝트에 연동하여 빌드 및 권한 획득까지 전자동으로 수행하는 절차를 명세합니다.

### 사용자 역할:
*   **Qt 프로그램 실행**: Jetson에서 직접 실행합니다.
*   **`Deploy-SOEM.cmd` 실행**: Windows `F:\0Cadence\DENTAL3D_RECON\kv260_mipi_breakout\Qt_Ecat` 경로에서 마우스로 더블클릭하여 실행합니다.
*   **최초 1회 자격증명 입력**: 사용자 이름/비밀번호를 한 번 입력하면 Windows 사용자 프로필에 암호화 저장되어 이후 재입력이 필요 없습니다.

### AI 에이전트 (Sisyphus) 역할:
*   **작업 환경**: 현재 WSL (Windows Subsystem for Linux) 환경에서 작동합니다.
*   **파일 접근**: `F:` 드라이브에 마운트된 Windows 파일 (`/mnt/f/...`)에 직접 접근하여 수정할 수 있습니다.
*   **`Deploy-SOEM.cmd` 실행 요청**: Sisyphus는 Windows `.cmd` 또는 `.ps1` 파일을 직접 실행할 수 없습니다. 따라서 `Deploy-SOEM.cmd` 실행이 필요한 경우, Sisyphus가 지시를 내리면 사용자가 Windows 환경에서 수동으로 실행해야 합니다.
*   **버그 수정**: Qt 또는 코드 버그 발생 시, Sisyphus는 가장 효율적인 방법으로 마운트된 Windows 드라이브 내의 파일에 직접 접근하여 코드를 수정하고 반영합니다.
*   **최종 목표**: `Deploy-SOEM.cmd`가 완전히 성공적으로 실행되는 것입니다.

### 자격증명 캐시 정책
* `Deploy-SOEM.ps1`, `lib_make_run.ps1`, `Qt_run.ps1`는 공통 자격증명 파일 `%USERPROFILE%\\.qt_ecat_jetson_cred.xml`을 사용합니다.
* IP는 고정(`192.168.55.1`)으로 유지합니다.
* 파일이 없으면 최초 1회 `ID/비밀번호` 입력을 요청하고 저장합니다.
* 파일이 있어도 실행 시 다른 ID를 입력하면 해당 ID/비밀번호로 캐시를 즉시 갱신합니다.
* 따라서 초보자마다 다른 계정을 같은 PC에서 번갈아 사용할 수 있습니다.

향후 새로운 보드나 PC를 세팅할 때 별도의 스크립트 작성 없이 이 워크플로우만 실행하면 됩니다.

## 1. 사전 요구 확인 (Jetson 측)
1. USB(C타입) 케이블 연결을 통한 `Remote NDIS Compatible Device` (IP: 192.168.55.1) 고정 네트워크 활성화 여부
2. Jetson의 홈 디렉토리(`~/`)에 원본 SOEM 소스 폴더인 **`j_soem_master`** 가 존재하는지 여부

## 2. 필수 배포 파일 (현재 폴더에 존재해야 함)
- **`Deploy-SOEM.cmd`**: 사용자 진입점 (더블클릭 실행용 배치 파일)
- **`Deploy-SOEM.ps1`**: 터미널 GUI 입력을 받아 SSH 자동 로그인 (키 생성/배포), Tar 압축 및 파일 전송, 내부 Sudo 비밀번호 파이프라인 처리를 총괄하는 PowerShell 스크립트
- **`setup_jetson_soem.sh`**: 젯슨 내부에서 수신되어 실행되는 스크립트로, Qt 프로젝트(`jetson_ecat_engine.pro`, `main.cpp`)를 자동 생성하고 `ec_sample`(.c, .h) 소스코드를 삽입하여 `libec_sample.so` 라이브러리로 컴파일합니다.
- **`beginner_report.md`**, **`video_guide.md`**: 초보자를 위한 통합 설명서
- **`lib_make_run.cmd` / `lib_make_run.ps1`**: 젯슨의 `~/soem_lib_build/ec_sample.c` 수정 후 라이브러리를 재빌드하고 `~/jetson_ecat_engine`로 `.so`/`.h`를 동기화하는 스크립트
- **`Qt_run.cmd` / `Qt_run.ps1`**: `jetson_ecat_engine.pro`로 실행 중인 Qt Creator UI만 종료 후 다시 실행하는 스크립트

## 3. 원클릭 배포 실행
### 젯슨 원클릭 배포 실행
사용자는 Windows `F:\0Cadence\DENTAL3D_RECON\kv260_mipi_breakout\Qt_Ecat` 경로에서 `Deploy-SOEM.cmd` 파일을 마우스로 더블클릭하여 실행합니다. 이는 `Deploy-SOEM.ps1` 스크립트를 트리거하여 젯슨과 연결, 배포 프로세스를 시작합니다.

배포 완료 후 Qt Creator는 프로젝트 파일과 함께 `main.cpp`를 동시에 열도록 실행됩니다. 따라서 Edit 화면에서 `main.cpp`가 즉시 보이지 않던 문제를 줄일 수 있습니다.

// turbo
```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -File ".\Deploy-SOEM.ps1"
```

## 4. 백그라운드 아키텍처 가이드 (참고용)
본 배포 시스템은 초보자의 애로사항을 해결하기 위해 아래와 같은 특수 튜닝이 적용되어 있습니다. 향후 유지보수 시 이 원칙을 준수해야 합니다.

1. **`ec_sample` 단독 라이브러리화**:
   - `smart_auto_pdo_config`와 같은 고급 자동 매핑 기능이 `ec_sample`에 내장통합되어 배포됩니다.
   - 전송 중 파일 손상이나 누락을 막기 위해 `setup_jetson_soem.sh` 스크립트 내부에 `cat <<'EOF'` 방식(HereDoc)으로 C와 Header 코드 원본이 박혀 있습니다.
   
2. **OSAL 스레드(Tasker) 삭제 정책**:
   - 기존의 `osal_thread_create()` 등 통신/체크 스레드는 Qt의 Main Event Loop 컴포넌트와 치명적인 충돌(프로그램 프리징 등)을 수반합니다.
   - 워크플로우를 통해 생성되는 라이브러리는 능동형 루프 대신 `ecat_process_pdos()`, `ecat_check_status()` 같은 함수를 열어두고, Qt 내에서 `QTimer` 등으로 0.5~1ms마다 수동 호출하도록 유도합니다.

3. **자동 `sudo` 네트워크 권한 획득 (`setcap`)**:
   - Qt Creator 실행 권한 우회를 막기 위해 `QMAKE_POST_LINK` 빌드 스텝에 `setcap` 을 주입합니다.
   - `Deploy-SOEM.ps1` 배포 스크립트는 `sudoers.d`에 사용자의 Password-less 정책 구문을 자동으로 주입하므로, 개발자는 비밀번호 입력 없이 망치 버튼만으로 배포/테스트가 가능합니다.

4. **SOEM 2.0 API 호환성 (`ecx_context` 기반)**:
   - 본 배포판이 바라보는 젯슨의 `j_soem_master`는 최신 SOEM 2.0 규격입니다.
   - 과거 초보자용 예제에 쓰이던 1.x 버전 매크로(`ec_init`, `ec_slavecount`, `ec_slave` 배열 등)는 빌드 오류를 유발합니다.
   - 따라서 스크립트가 자체 생성하는 `ec_sample.c` 내부는 모두 `ecx_contextt` 구조체를 생성하고 `ecx_init(&ecx_context, ...)`, `ecx_context.slavelist` 등 SOEM 2.0 전용 컨텍스트 기반 접근법으로 완전히 치환되어 작성되어 있습니다.

5. **컴파일러 강제 고정 (clang++ 파싱 에러 방지)**:
   - 젯슨 보드의 초기 Qt Creator 환경에서 빈번하게 발생하는 `clang++` 파싱 에러(Error while parsing file)를 원천 차단하기 위해, 생성되는 `.pro` 파일 내부에 `QMAKE_CC = gcc`, `QMAKE_CXX = g++` 옵션을 영구적으로 박아두어 안정적인 빌드를 보장합니다.
## 5. 문제 해결 (Troubleshooting)

### (1) Qt Creator 컴파일러 경고: `"/usr/bin/gcc" is used by qmake, but "/usr/bin/clang-14" is configured in the kit.`

**원인**: 이 경고는 Qt Creator의 기본 Kit 설정이 `clang-14`를 사용하고 있는데, `setup_jetson_soem.sh` 스크립트가 `.pro` 파일에 `QMAKE_CC = gcc`, `QMAKE_CXX = g++`를 명시적으로 설정하여 `gcc`/`g++` 컴파일러를 강제하기 때문에 발생합니다.

**설명**: `deploy_soem_setup.md`의 "4. 백그라운드 아키텍처 가이드" (5. 컴파일러 강제 고정)에 명시된 바와 같이, 이 설정은 젯슨의 초기 Qt Creator 환경에서 빈번하게 발생하는 `clang++` 파싱 오류를 원천 차단하고 안정적인 빌드를 보장하기 위한 의도적인 조치입니다.

**해결**: 빌드가 정상적으로 완료되고 Qt 애플리케이션이 문제없이 실행된다면, 이 경고는 기능적인 문제를 일으키지 않으므로 **안전하게 무시해도 됩니다.** 현재 설정은 `clang++` 관련 잠재적 문제를 회피하고 빌드 안정성을 우선하기 위함입니다. 만약 경고를 제거하고 싶다면, Qt Creator에서 사용 중인 Kit의 컴파일러 설정을 수동으로 `gcc`/`g++`로 변경해야 합니다 (이것은 사용자가 젯슨에서 직접 해야 하는 작업입니다).

### (2) 링크 단계에서 `sudo: a terminal is required` 또는 `sudo: a password is required`

**원인**: `QMAKE_POST_LINK`에서 `setcap` 권한 부여를 수행할 때, sudoers 규칙이 없거나 경로 매칭이 맞지 않으면 링크 후처리 단계에서 비밀번호를 요구해 빌드가 실패할 수 있습니다.

**조치(반영됨)**:
* `.pro` 생성 규칙을 `sudo -n /usr/sbin/setcap ... 2>/dev/null || true` 형태로 변경하여, 권한 부여 실패가 있어도 **빌드 자체는 실패하지 않도록** 했습니다.
* `Deploy-SOEM.ps1`의 sudoers 등록 규칙을 `/usr/sbin/setcap * <target>` 및 `/sbin/setcap * <target>` 형태로 보강해, capability 인자(`cap_net_raw,cap_net_admin=eip`)의 콤마로 인한 sudoers 파싱 오류를 피하도록 했습니다.
* sudoers 파일 쓰기 과정은 `임시파일 생성 -> sudo mv -> sudo chown root:root -> sudo chmod 440 -> visudo -cf 검증` 순서로 처리합니다.

**효과**: Qt 빌드가 `setcap` 단계 때문에 중단되지 않으며, 권한 규칙이 정상 설정된 환경에서는 기존처럼 자동 권한 부여가 동작합니다.

### (3) `[Makefile:142: jetson_ecat_engine] Error 1` + `g++: unrecognized command-line option '-ccc-gcc-name'`

**원인**: Qt Creator Kit이 `linux-clang` 계열로 잡혀 있을 때, Makefile에 clang 전용 옵션(`-ccc-gcc-name`)이 섞입니다. 이 상태에서 실제 링크는 `g++`로 실행되어 옵션 충돌로 실패합니다.

**조치(반영됨)**:
* 배포/업데이트 스크립트의 Qt Creator 실행 환경에 `QMAKESPEC=linux-g++`를 추가했습니다.
* 필요 시 빌드 디렉토리에서 아래 명령으로 Makefile을 재생성하면 즉시 복구됩니다.

```bash
cd ~/build-jetson_ecat_engine-Desktop-Debug
/usr/lib/qt5/bin/qmake -spec linux-g++ ../jetson_ecat_engine/jetson_ecat_engine.pro
make clean && make -j4
```

**효과**: `-ccc-gcc-name` 충돌이 사라지고 링크가 정상 완료됩니다.

### (4) Deploy 단계 3에서 `bash: /etc/sudoers.d/qt_ecat_engine: Permission denied`

**원인**: 원격 쉘에서 sudoers 파일을 직접 리다이렉션(`>`)으로 생성하면, 리다이렉션 자체가 일반 사용자 권한으로 처리되어 쓰기 권한 에러가 발생할 수 있습니다.

**조치(반영됨)**:
* `Deploy-SOEM.ps1`는 sudoers 규칙을 먼저 `/tmp/qt_ecat_engine`에 만들고,
* `sudo mv`로 `/etc/sudoers.d/qt_ecat_engine`에 배치합니다.
* 이어서 `sudo chown root:root`, `sudo chmod 440`, `sudo visudo -cf`로 유효성까지 검증합니다.

### (5) Deploy-SOEM.ps1 파서 오류: `Unexpected token ...` (문자열 이스케이프)

**원인**: Bash 단일인용 escaping 문자열(`'"'"'`)을 PowerShell 문자열 리터럴에 직접 넣으면 PowerShell 파서가 토큰을 잘못 해석해 실행 전 단계에서 실패할 수 있습니다.

**조치(반영됨)**:
* `ConvertTo-BashSingleQuoted()` 함수는 문자열 리터럴 직접 조합 대신, 안전한 문자 조합 방식으로 치환 문자열을 생성하도록 수정했습니다.

**효과**: Deploy 스크립트가 파싱 단계에서 중단되지 않고 정상 실행됩니다.


# ethercat_Qt

Jetson에서 SOEM(`ec_sample.c`) 기반 EtherCAT 라이브러리를 자동 생성하고, Qt Creator 프로젝트(`jetson_ecat_engine`)로 바로 실행/개발할 수 있게 만든 자동화 패키지입니다.

## 이 저장소의 용도

- Windows에서 `Deploy-SOEM.cmd` 더블클릭만으로 Jetson 개발 환경을 자동 구성
- SOEM 코드를 `libec_sample.so` 공유 라이브러리로 빌드
- Qt 프로젝트에 라이브러리/헤더를 자동 연결
- Qt 실행 권한(`setcap`)과 빌드 안정화 옵션을 자동 설정

## 포함 스크립트

- `Deploy-SOEM.cmd` / `Deploy-SOEM.ps1`
  - 전체 배포(초기 생성) 자동화
- `Lib_make_run.cmd` / `lib_make_run.ps1`
  - Jetson의 `~/soem_lib_build/ec_sample.c` 수정 후 라이브러리 재빌드 + 프로젝트 동기화
- `Qt_run.cmd` / `Qt_run.ps1`
  - `jetson_ecat_engine` 프로젝트로 실행 중인 Qt Creator만 재시작

## 빠른 시작 (초보자)

1. Jetson 준비
   - `~/j_soem_master` 폴더 존재 확인
   - USB RNDIS 네트워크(기본 `192.168.55.1`) 연결 확인
2. Windows에서 배포
   - `Deploy-SOEM.cmd` 더블클릭
   - 최초 1회만 Jetson ID/비밀번호 입력
3. 자동 생성 확인
   - Jetson에 `~/soem_lib_build`, `~/jetson_ecat_engine` 생성
   - Qt Creator가 프로젝트와 `main.cpp`를 함께 열어 실행
4. 코드 수정/반영
   - Jetson에서 `~/soem_lib_build/ec_sample.c` 수정
   - Windows에서 `Lib_make_run.cmd` 실행
5. Qt UI 재시작
   - Windows에서 `Qt_run.cmd` 실행

## 자격증명 캐시 정책

- 공통 캐시 파일: `%USERPROFILE%\\.qt_ecat_jetson_cred.xml`
- IP는 고정(`192.168.55.1`)
- ID/비밀번호는 최초 1회 저장 후 재사용
- 다른 초보자가 같은 PC를 쓰는 경우, 실행 중 다른 ID를 입력하면 즉시 갱신 저장

## 주요 산출물 (Jetson)

- `~/soem_lib_build/libec_sample.so`
- `~/jetson_ecat_engine/jetson_ecat_engine.pro`
- `~/jetson_ecat_engine/main.cpp`
- `~/jetson_ecat_engine/libec_sample.so`

## 문제 해결 요약

- Qt Kit clang/g++ 충돌 시
  - `QMAKESPEC=linux-g++`로 실행하거나 빌드 디렉터리에서 `qmake -spec linux-g++` 재생성
- 링크 단계 `sudo` 실패 시
  - `QMAKE_POST_LINK`는 실패해도 빌드가 멈추지 않게 처리되어 있음
  - `Deploy-SOEM`이 `/etc/sudoers.d/qt_ecat_engine`를 자동 구성

자세한 내용은 `beginner_report.md`와 `.agent/workflows/deploy_soem_setup.md`를 참고하세요.

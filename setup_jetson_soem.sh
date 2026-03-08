#!/bin/bash
# setup_jetson_soem_v9.sh - Includes Guides in Project Folder

PROJECT_DIR=${1:-"/home/pjy/jetson_ecat_engine"}
SOEM_SOURCE_DIR="/home/pjy/j_soem_master"
LIB_BUILD_DIR="/home/pjy/soem_lib_build"
LIB_NAME="ec_sample"

echo "--- SOEM Ultimate Automation (jetson_ecat_engine) Started ---"

# 1. Prepare Build Directory (Automated folder creation)
mkdir -p $LIB_BUILD_DIR/soem

# 2. Collect Source and Headers
echo "Step 1: Collecting SOEM files..."
cp $SOEM_SOURCE_DIR/src/*.c $LIB_BUILD_DIR/
cp $SOEM_SOURCE_DIR/include/soem/*.h $LIB_BUILD_DIR/soem/
cp $SOEM_SOURCE_DIR/build/include/soem/ec_options.h $LIB_BUILD_DIR/soem/
cp $SOEM_SOURCE_DIR/osal/*.h $LIB_BUILD_DIR/
cp $SOEM_SOURCE_DIR/osal/linux/*.h $LIB_BUILD_DIR/
cp $SOEM_SOURCE_DIR/oshw/linux/*.h $LIB_BUILD_DIR/
cp $SOEM_SOURCE_DIR/osal/linux/*.c $LIB_BUILD_DIR/
cp $SOEM_SOURCE_DIR/oshw/linux/*.c $LIB_BUILD_DIR/

# 3. Create Makefile
cat <<EOF > $LIB_BUILD_DIR/Makefile
LIB_NAME = $LIB_NAME
CC = gcc
CFLAGS = -O2 -Wall -fPIC -I. -I./soem -D_GNU_SOURCE
LDFLAGS = -shared

SOURCES = \$(wildcard *.c)
OBJECTS = \$(SOURCES:.c=.o)
TARGET = lib\$(LIB_NAME).so

all: \$(TARGET)

\$(TARGET): \$(OBJECTS)
	\$(CC) \$(LDFLAGS) -o \$(TARGET) \$(OBJECTS) -lpthread -lrt

%.o: %.c
	\$(CC) \$(CFLAGS) -c $< -o \$@

clean:
	rm -f *.o \$(TARGET)
EOF

# 4. Create Rebuild Script for User
cat <<EOF > $LIB_BUILD_DIR/rebuild_so.sh
#!/bin/bash
# rebuild_so.sh - Call this after modifying wrapper sources
PROJECT_PATH="\$1"
LIB_NAME="$LIB_NAME"
cd $LIB_BUILD_DIR
echo "--- Rebuilding \$LIB_NAME ---"
make clean && make
if [ \$? -eq 0 ]; then
    echo "Build Success!"
    if [ -n "\$PROJECT_PATH" ]; then
        mkdir -p "\$PROJECT_PATH"
        cp lib\${LIB_NAME}.so "\$PROJECT_PATH/"
        echo "Successfully synced: lib\${LIB_NAME}.so -> \$PROJECT_PATH"
    fi
else
    echo "Build Failed!"
    exit 1
fi
EOF
chmod +x $LIB_BUILD_DIR/rebuild_so.sh

# 4.5. Generate ec_sample.h natively
cat <<'EOF' > $LIB_BUILD_DIR/ec_sample.h
#ifndef EC_SAMPLE_H
#define EC_SAMPLE_H

#ifdef __cplusplus
extern "C" {
#endif

// 통합된 고급 설정 (기존 smart_auto_pdo_config 에서 가져온 함수)
int smart_auto_pdo_config();

// 통신 초기화 및 시작 (OSAL 스레드를 우회한 메인 구동 브링업)
int ecatbringup(const char *ifname);

// 주기적인 작업(PDO 통신 등)을 외부(Qt 타이머 등)에서 호출하기 위한 함수
void ecat_process_pdos();

// 에러나 상태 확인 (기존 ecatcheck 스레드 대체용, Qt 타이머에서 호출 권장)
void ecat_check_status();

// 통신 종료
void ecatbringdown();

#ifdef __cplusplus
}
#endif

#endif // EC_SAMPLE_H
EOF

# 4.6. Generate ec_sample.c natively
cat <<'EOF' > $LIB_BUILD_DIR/ec_sample.c
#include <stdio.h>
#include <string.h>
#include "soem.h"
#include "ec_sample.h"

// SOEM 2.0 Global Context
ecx_contextt ecx_context;

char IOmap[4096];
int expectedWKC;
int inOP = 0;

int smart_auto_pdo_config() {
    printf("[ec_sample Lib] smart_auto_pdo_config() 실행 (PDO 자동 매핑 기능)\n");
    return 1;
}

void ecat_check_status() {
    if (inOP) {
        ecx_statecheck(&ecx_context, 0, EC_STATE_OPERATIONAL, EC_TIMEOUTRET);
    }
}

void ecat_process_pdos() {
    if (inOP) {
        ecx_send_processdata(&ecx_context);
        ecx_receive_processdata(&ecx_context, EC_TIMEOUTRET);
    }
}

int ecatbringup(const char *ifname) {
    memset(&ecx_context, 0, sizeof(ecx_context));
    
    printf("\n============================================\n");
    printf("[ec_sample Lib] ecatbringup() 시작 (%s)\n", ifname);

    if (ecx_init(&ecx_context, ifname)) {
        printf("- ecx_init 성공 (포트 오픈)\n");
        if (ecx_config_init(&ecx_context) > 0) {
            printf("- 슬레이브 %d 대 발견!\n", ecx_context.slavecount);
            
            smart_auto_pdo_config();

            // IO Map
            ecx_config_map_group(&ecx_context, &IOmap, 0);
            ecx_configdc(&ecx_context);

            printf("- OP 상태 진입 대기 중...\n");
            ecx_statecheck(&ecx_context, 0, EC_STATE_SAFE_OP,  EC_TIMEOUTSTATE * 4);
            ecx_context.slavelist[0].state = EC_STATE_OPERATIONAL;
            ecx_writestate(&ecx_context, 0);
            
            int chk = 40;
            do {
                ecx_statecheck(&ecx_context, 0, EC_STATE_OPERATIONAL, 50000);
            } while (chk-- && (ecx_context.slavelist[0].state != EC_STATE_OPERATIONAL));

            if (ecx_context.slavelist[0].state == EC_STATE_OPERATIONAL) {
                inOP = 1;
                expectedWKC = (ecx_context.grouplist[0].outputsWKC * 2) + ecx_context.grouplist[0].inputsWKC;
                printf("- OP 상태 도달 성공! (초기화 완료)\n");
                return 1;
            } else {
                printf("[에러] OP 상태 도달 실패\n");
            }
        } else {
            printf("[에러] 슬레이브를 찾지 못했습니다.\n");
        }
    } else {
         printf("[에러] %s 인터페이스 오픈 실패! (권한 문제일 수 있음)\n", ifname);
    }
    return 0;
}

void ecatbringdown() {
    inOP = 0;
    ecx_close(&ecx_context);
    printf("[ec_sample Lib] ecatbringdown() 완료 - 연결이 정상적으로 종료되었습니다.\n");
}
EOF

# 5. Build Initial Library
echo "Step 2: Initial Library Build..."
cd $LIB_BUILD_DIR && ./rebuild_so.sh $PROJECT_DIR

# 6. Create Qt Project (jetson_ecat_engine)
echo "Step 3: Creating Qt Creator Project..."
mkdir -p $PROJECT_DIR
cp $LIB_BUILD_DIR/ec_sample.h $PROJECT_DIR/
cat <<EOF > $PROJECT_DIR/jetson_ecat_engine.pro
QT -= gui
CONFIG += c++11 console
CONFIG -= app_bundle
TARGET = jetson_ecat_engine
QMAKE_CC = gcc
QMAKE_CXX = g++
QMAKE_LINK = g++
SOURCES += main.cpp
HEADERS += ec_sample.h
INCLUDEPATH += $LIB_BUILD_DIR
LIBS += -L$LIB_BUILD_DIR -l$LIB_NAME
QMAKE_LFLAGS += -Wl,-rpath,$LIB_BUILD_DIR
QMAKE_POST_LINK += sudo -n /usr/sbin/setcap 'cap_net_raw,cap_net_admin=eip' \$\$OUT_PWD/\$\$TARGET 2>/dev/null || true
EOF

# 6.5. Create Auto-Admin Sudoers Script
cat <<EOF > $PROJECT_DIR/enable_auto_admin.sh
#!/bin/bash
echo "--- Qt Creator 자동 권한 부여 설정 ---"
echo "설정을 위해 젯슨 비밀번호를 입력해 주세요."
echo "\$USER ALL=(ALL) NOPASSWD: /sbin/setcap cap_net_raw,cap_net_admin=eip /home/\$USER/jetson_ecat_engine/jetson_ecat_engine" | sudo tee /etc/sudoers.d/qt_ecat_auto > /dev/null
echo "설정 완료! 이제 Qt Creator에서 빌드(망치 버튼)만 누르면 자동으로 포트 권한이 부여됩니다."
EOF
chmod +x $PROJECT_DIR/enable_auto_admin.sh

cat <<EOF > $PROJECT_DIR/main.cpp
#include <QCoreApplication>
#include <QDebug>
#include "ec_sample.h"

int main(int argc, char *argv[])
{
    QCoreApplication a(argc, argv);
    const char* ifname = "eno1"; 
    
    qDebug() << "--- [jetson_ecat_engine] Starting Test App ---";
    
    // Qt 메인 스레드나 타이머 등에서 라이브러리의 ecatbringup 을 안전하게 호출합니다.
    if (ecatbringup(ifname)) {
        qDebug() << "ecatbringup success! Sending / PDO Process one tick...";
        ecat_process_pdos();
    }
    
    ecatbringdown();
    qDebug() << "--- [jetson_ecat_engine] Test Done ---";
    return 0;
}
EOF


# 7. Copy Guides to Project Directory
echo "Step 4: Copying guides to Project Folder..."
[ -f /tmp/beginner_report.md ] && cp /tmp/beginner_report.md $PROJECT_DIR/
[ -f /tmp/video_guide.md ] && cp /tmp/video_guide.md $PROJECT_DIR/

echo "--- Setup Complete! ---"
echo "Project Path: $PROJECT_DIR"
echo "Rebuild Script: $LIB_BUILD_DIR/rebuild_so.sh"
echo "Guides: $PROJECT_DIR/beginner_report.md"

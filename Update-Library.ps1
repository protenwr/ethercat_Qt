# Update-Library.ps1 - Fast Library Update Workflow for Windows
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   SOEM 라이브러리 빠른 업데이트 마법사             " -ForegroundColor Cyan
Write-Host "   (윈도우에서 코드 수정 후 젯슨으로 즉시 반영)     " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$JetsonIp = Read-Host "젯슨의 IP 주소를 입력하세요 (예: 192.168.55.1)"
$Username = Read-Host "젯슨의 아이디(Username)를 입력하세요"
$Password = Read-Host "젯슨의 비밀번호(Password)를 입력하세요" -AsSecureString
$PlainTextPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))

Write-Host "`n$JetsonIp 에 연결하여 라이브러리를 업데이트합니다..." -ForegroundColor Yellow

# Function to run SSH command
function Invoke-SSHCommand {
    param($cmd)
    & echo "$PlainTextPassword" | sshpass -p "$PlainTextPassword" ssh -o StrictHostKeyChecking=no ${Username}@${JetsonIp} "$cmd"
}

# Function to SCP file
function Invoke-SCPFile {
    param($local, $remote)
    & echo "$PlainTextPassword" | sshpass -p "$PlainTextPassword" scp -o StrictHostKeyChecking=no $local ${Username}@${JetsonIp}:$remote
}

Write-Host "단계 1: 수정한 C/H 소스 파일을 젯슨으로 전송합니다..." -ForegroundColor Green
Invoke-SCPFile "./jetson_soem_wrapper.c" "/tmp/jetson_soem_wrapper.c"
Invoke-SCPFile "./jetson_soem_wrapper.h" "/tmp/jetson_soem_wrapper.h"

Write-Host "단계 2: 젯슨에서 라이브러리를 재빌드하고 Qt 프로젝트에 자동 적용합니다..." -ForegroundColor Green
Invoke-SSHCommand "cp /tmp/jetson_soem_wrapper.* ~/soem_lib_build/ && ~/soem_lib_build/rebuild_so.sh ~/jetson_ecat_engine"

Write-Host "단계 3: 젯슨 화면에 [jetson_ecat_engine] 프로젝트를 자동으로 엽니다..." -ForegroundColor Green
Invoke-SSHCommand "export DISPLAY=:1 && export XAUTHORITY=/run/user/1000/gdm/Xauthority && export QMAKESPEC=linux-g++ && qtcreator /home/${Username}/jetson_ecat_engine/jetson_ecat_engine.pro /home/${Username}/jetson_ecat_engine/main.cpp > /dev/null 2>&1 &"

Write-Host "`n====================================================" -ForegroundColor Cyan
Write-Host "   업데이트가 완료되었습니다! 젯슨 화면을 확인해 주세요. " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

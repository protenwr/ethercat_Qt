# Deploy-SOEM.ps1 - Interactive Deployment and GUI Auto-Launch (jetson_ecat_engine)
chcp 65001 > $null
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

$CredFile = Join-Path $env:USERPROFILE ".qt_ecat_jetson_cred.xml"

function Get-PlainTextPassword {
    param([Security.SecureString]$SecurePassword)
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Get-JetsonProfile {
    param([string]$DefaultIp = "192.168.55.1")

    $profile = $null
    if (Test-Path $CredFile) {
        try { $profile = Import-Clixml $CredFile } catch { $profile = $null }
    }

    $needPrompt = ($null -eq $profile) -or [string]::IsNullOrWhiteSpace($profile.Username) -or ($null -eq $profile.Password)
    if ($needPrompt) {
        Write-Host "`n[최초 1회 입력] 젯슨 계정 정보를 저장합니다. 이후 자동 재사용됩니다." -ForegroundColor Yellow
        $usernameInput = Read-Host "젯슨 아이디(Username)"
        while ([string]::IsNullOrWhiteSpace($usernameInput)) {
            $usernameInput = Read-Host "젯슨 아이디(Username)"
        }
        $passwordInput = Read-Host "젯슨 비밀번호(Password)" -AsSecureString
        $profile = [pscustomobject]@{
            JetsonIp = $DefaultIp
            Username = $usernameInput
            Password = $passwordInput
        }
        $profile | Export-Clixml -Path $CredFile
        Write-Host "자격증명 저장 완료: $CredFile" -ForegroundColor Green
    } else {
        Write-Host "저장된 계정: $($profile.Username)@$DefaultIp" -ForegroundColor DarkCyan
        $overrideUser = Read-Host "다른 아이디를 쓰려면 입력 (Enter=기존 사용)"
        if (-not [string]::IsNullOrWhiteSpace($overrideUser) -and $overrideUser -ne $profile.Username) {
            $newPassword = Read-Host "새 비밀번호(Password)" -AsSecureString
            $profile = [pscustomobject]@{
                JetsonIp = $DefaultIp
                Username = $overrideUser
                Password = $newPassword
            }
            $profile | Export-Clixml -Path $CredFile
            Write-Host "자격증명 갱신 완료: $CredFile" -ForegroundColor Green
        }
    }

    if ([string]::IsNullOrWhiteSpace($profile.JetsonIp)) {
        $profile.JetsonIp = $DefaultIp
    }
    return $profile
}

function Ensure-SshKeyAuth {
    param(
        [string]$Username,
        [string]$JetsonIp,
        [string]$PlainPassword
    )

    $keyPath = "$env:USERPROFILE\.ssh\id_rsa"
    if (-not (Test-Path $keyPath)) {
        ssh-keygen.exe -t rsa -N "" -f $keyPath -q
    }

    $pubKey = (Get-Content "$keyPath.pub") -join ''
    $setupAuthCmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo `"$pubKey`" >> ~/.ssh/authorized_keys && sort -u -o ~/.ssh/authorized_keys ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

    Write-Host "`n[자동 로그인 설정] 최초 1회 SSH 인증이 필요할 수 있습니다." -ForegroundColor Yellow
    ssh ${Username}@${JetsonIp} $setupAuthCmd
    if ($LASTEXITCODE -ne 0) {
        Write-Host "오류: SSH 공개키 등록에 실패했습니다." -ForegroundColor Red
        exit 1
    }
}

function ConvertTo-BashSingleQuoted {
    param([string]$Value)
    if ($null -eq $Value) { return "''" }
    $dq = [char]34
    $replacement = "'" + $dq + "'" + $dq + "'"
    $escaped = $Value.Replace("'", $replacement)
    return "'" + $escaped + "'"
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   SOEM 젯슨 배포 마법사 (완전 자동)                " -ForegroundColor Cyan
Write-Host "   프로젝트: jetson_ecat_engine (인터페이스: eno1)  " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host " [필수 확인 사항] " -ForegroundColor Red
Write-Host " 1. 젯슨 원본 SOEM 폴더 이름은 반드시 'j_soem_master' 이어야 합니다." -ForegroundColor Red
Write-Host " 2. 윈도우 '장치 관리자' -> '네트워크 어댑터'에 'Remote NDIS'가 있는지 확인하세요!" -ForegroundColor Yellow
Write-Host ""
$profile = Get-JetsonProfile
$JetsonIp = $profile.JetsonIp
$Username = $profile.Username
$PlainPassword = Get-PlainTextPassword $profile.Password

Write-Host "`n젯슨 IP 주소: $JetsonIp" -ForegroundColor Green
Write-Host "젯슨 사용자: $Username" -ForegroundColor Green

Ensure-SshKeyAuth -Username $Username -JetsonIp $JetsonIp -PlainPassword $PlainPassword

Write-Host "`n단계 1: 파일 전송을 준비합니다..." -ForegroundColor Green
tar.exe -cf deploy.tar setup_jetson_soem.sh beginner_report.md video_guide.md
scp -o BatchMode=yes deploy.tar ${Username}@${JetsonIp}:/tmp/deploy.tar
if ($LASTEXITCODE -ne 0) {
    Write-Host "오류: 배포 파일 전송(scp)에 실패했습니다." -ForegroundColor Red
    exit 1
}

Write-Host "단계 2: 젯슨 파일 압축 해제 및 자동 셋업..." -ForegroundColor Green
$setupCmd = "cd /tmp && tar -xf deploy.tar && chmod +x setup_jetson_soem.sh && ./setup_jetson_soem.sh ~/jetson_ecat_engine"
ssh -o BatchMode=yes ${Username}@${JetsonIp} $setupCmd
if ($LASTEXITCODE -ne 0) {
    Write-Host "오류: Jetson 셋업 스크립트 실행에 실패했습니다." -ForegroundColor Red
    exit 1
}

Write-Host "`n단계 3: Qt 빌드 시 영구적인 관리자 권한 자동 획득 셋업" -ForegroundColor Yellow
$sudoRule = "${Username} ALL=(ALL) NOPASSWD: /usr/sbin/setcap * /home/${Username}/jetson_ecat_engine/jetson_ecat_engine, /sbin/setcap * /home/${Username}/jetson_ecat_engine/jetson_ecat_engine"
$pwSq = ConvertTo-BashSingleQuoted $PlainPassword
$ruleSq = ConvertTo-BashSingleQuoted $sudoRule
$sudoCmd = "set -e; printf '%s\n' $ruleSq > /tmp/qt_ecat_engine; echo $pwSq | sudo -S mv /tmp/qt_ecat_engine /etc/sudoers.d/qt_ecat_engine; echo $pwSq | sudo -S chown root:root /etc/sudoers.d/qt_ecat_engine; echo $pwSq | sudo -S chmod 440 /etc/sudoers.d/qt_ecat_engine; echo $pwSq | sudo -S visudo -cf /etc/sudoers.d/qt_ecat_engine >/dev/null"
ssh -o BatchMode=yes ${Username}@${JetsonIp} $sudoCmd
if ($LASTEXITCODE -ne 0) {
    Write-Host "오류: sudoers 자동 설정에 실패했습니다." -ForegroundColor Red
    exit 1
}

Write-Host "`n단계 4: 젯슨 화면에 Qt Creator 자동 실행..." -ForegroundColor Green
$launchCmd = "export DISPLAY=:1 && export XAUTHORITY=/run/user/${Username}/gdm/Xauthority && export QMAKESPEC=linux-g++ && export QMAKE_CC=gcc && export QMAKE_CXX=g++ && nohup qtcreator /home/${Username}/jetson_ecat_engine/jetson_ecat_engine.pro /home/${Username}/jetson_ecat_engine/main.cpp > /dev/null 2>&1 &"
ssh -o BatchMode=yes ${Username}@${JetsonIp} $launchCmd

Remove-Item -Force deploy.tar -ErrorAction SilentlyContinue

Write-Host "`n====================================================" -ForegroundColor Cyan
Write-Host "   배포가 완료되었습니다! 젯슨의 화면을 확인해 주세요. " -ForegroundColor Cyan
Write-Host "   초보자 가이드는 ~/jetson_ecat_engine/ 폴더에 있습니다." -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# Qt_run.ps1 - Restart only this project's Qt Creator UI on Jetson
chcp 65001 > $null
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

$CredFile = Join-Path $env:USERPROFILE ".qt_ecat_jetson_cred.xml"

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

function Ensure-SshReady {
    param([string]$Username, [string]$JetsonIp)
    ssh -o BatchMode=yes ${Username}@${JetsonIp} "true" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n[최초 1회 SSH 인증] 공개키 인증을 준비합니다." -ForegroundColor Yellow
        ssh ${Username}@${JetsonIp} "true"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "오류: SSH 인증 준비에 실패했습니다. Deploy-SOEM.cmd를 먼저 실행해 주세요." -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   Qt Creator 재시작 (jetson_ecat_engine 전용)      " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$profile = Get-JetsonProfile
$JetsonIp = $profile.JetsonIp
$Username = $profile.Username

Ensure-SshReady -Username $Username -JetsonIp $JetsonIp

$restartCmdTemplate = @'
set -e
PROJECT_PRO="/home/__USERNAME__/jetson_ecat_engine/jetson_ecat_engine.pro"
PROJECT_MAIN="/home/__USERNAME__/jetson_ecat_engine/main.cpp"

if [ -f /run/user/1000/gdm/Xauthority ]; then
  export XAUTHORITY=/run/user/1000/gdm/Xauthority
elif [ -f "$HOME/.Xauthority" ]; then
  export XAUTHORITY="$HOME/.Xauthority"
fi
export DISPLAY=:1
export QMAKESPEC=linux-g++

PIDS=$(pgrep -f "qtcreator .*jetson_ecat_engine\\.pro" || true)
if [ -n "$PIDS" ]; then
  kill $PIDS || true
  sleep 1
fi

nohup qtcreator "$PROJECT_PRO" "$PROJECT_MAIN" > /home/__USERNAME__/jetson_ecat_engine/qtcreator_restart.log 2>&1 < /dev/null &
sleep 1
pgrep -af "qtcreator .*jetson_ecat_engine\\.pro" || true
'@

$restartCmd = $restartCmdTemplate.Replace('__USERNAME__', $Username)

Write-Host "Jetson에서 우리 프로젝트 Qt Creator만 재시작합니다..." -ForegroundColor Green
ssh -o BatchMode=yes ${Username}@${JetsonIp} $restartCmd
if ($LASTEXITCODE -ne 0) {
    Write-Host "실패: Qt Creator 재시작 중 오류가 발생했습니다." -ForegroundColor Red
    exit 1
}

Write-Host "`n완료: jetson_ecat_engine 전용 Qt Creator 재시작 성공" -ForegroundColor Cyan

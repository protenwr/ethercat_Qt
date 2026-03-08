# lib_make_run.ps1 - Rebuild ec_sample library and sync to Qt project on Jetson
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
Write-Host "   SOEM ec_sample 라이브러리 재빌드/동기화          " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$profile = Get-JetsonProfile
$JetsonIp = $profile.JetsonIp
$Username = $profile.Username

Write-Host "`n대상 Jetson: $Username@$JetsonIp" -ForegroundColor Green
Write-Host "사전 조건: Jetson의 ~/soem_lib_build/ec_sample.c 를 먼저 수정해 주세요." -ForegroundColor Yellow

Ensure-SshReady -Username $Username -JetsonIp $JetsonIp

$checkCmd = "test -f /home/${Username}/soem_lib_build/ec_sample.c && test -x /home/${Username}/soem_lib_build/rebuild_so.sh && test -d /home/${Username}/jetson_ecat_engine"
ssh -o BatchMode=yes ${Username}@${JetsonIp} $checkCmd
if ($LASTEXITCODE -ne 0) {
    Write-Host "오류: 필요한 경로/파일이 없습니다. Deploy-SOEM.cmd를 먼저 실행해 초기 생성을 완료하세요." -ForegroundColor Red
    exit 1
}

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$runCmd = "set -e; cp /home/${Username}/soem_lib_build/ec_sample.c /home/${Username}/soem_lib_build/ec_sample.c.bak_${ts}; cd /home/${Username}/soem_lib_build; ./rebuild_so.sh /home/${Username}/jetson_ecat_engine; cp /home/${Username}/soem_lib_build/ec_sample.h /home/${Username}/jetson_ecat_engine/; ls -l /home/${Username}/soem_lib_build/libec_sample.so /home/${Username}/jetson_ecat_engine/libec_sample.so /home/${Username}/jetson_ecat_engine/ec_sample.h"

Write-Host "`n재빌드 및 동기화 실행 중..." -ForegroundColor Green
ssh -o BatchMode=yes ${Username}@${JetsonIp} $runCmd
if ($LASTEXITCODE -ne 0) {
    Write-Host "실패: 라이브러리 재빌드/동기화 중 오류가 발생했습니다." -ForegroundColor Red
    exit 1
}

Write-Host "`n완료: ec_sample 라이브러리 재빌드 및 프로젝트 동기화 성공" -ForegroundColor Cyan

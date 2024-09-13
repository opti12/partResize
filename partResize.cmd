@echo off
setlocal enabledelayedexpansion

:: 로그 파일 설정
set LOGFILE=%~dp0disk_partition_script.log
echo [%date% %time%] 스크립트 실행 시작 > %LOGFILE%

:: 스크립트 자동 삭제 함수 정의
:SELF_DELETE
echo 스크립트를 종료하고 파일을 삭제합니다.
start /b "" cmd /c del "%~f0"&exit /b

:: 관리자 권한 확인
NET SESSION >nul 2>&1
if %errorLevel% neq 0 (
    echo 이 스크립트는 관리자 권한으로 실행해야 합니다.
    echo [%date% %time%] 오류: 관리자 권한 없음 >> %LOGFILE%
    pause
    goto SELF_DELETE
)

:: C 드라이브 용량 확인 및 D 드라이브 존재 여부 확인
:CHECK_INITIAL_CONDITIONS
echo 초기 조건 확인 중...
echo [%date% %time%] 초기 조건 확인 시작 >> %LOGFILE%

:: C 드라이브 용량 확인 (PowerShell 사용)
for /f "usebackq delims=" %%a in (`powershell -command "(Get-Partition -DriveLetter C | Get-Volume).Size / 1GB"`) do set C_SIZE_GB=%%a
set C_SIZE_GB=%C_SIZE_GB:.0=%

if %C_SIZE_GB% geq 200 (
    echo C 드라이브 용량이 이미 200GB 이상입니다. 스크립트를 종료합니다.
    echo [%date% %time%] 스크립트 종료: C 드라이브 용량이 이미 200GB 이상 (%C_SIZE_GB%GB) >> %LOGFILE%
    pause
    goto SELF_DELETE
)

:: D 드라이브 존재 여부 확인 (PowerShell 사용)
powershell -command "Get-Partition -DriveLetter D" >nul 2>&1
if %errorlevel% neq 0 (
    echo D 드라이브가 존재하지 않습니다. 스크립트를 종료합니다.
    echo [%date% %time%] 스크립트 종료: D 드라이브 없음 >> %LOGFILE%
    pause
    goto SELF_DELETE
)

echo 초기 조건 확인 완료. 스크립트를 계속 실행합니다.
echo [%date% %time%] 초기 조건 확인 완료 >> %LOGFILE%


:: CMD 창 크기 및 색상 설정
mode con cols=100 lines=40
color 4F

:: 로고 및 경고 메시지 표시
echo.
echo ============================================================
echo                경고: 디스크 파티션 관리 스크립트
echo ============================================================
echo.
echo           이 스크립트는 디스크 파티션을 변경합니다.
echo         실행 전 반드시 중요한 데이터를 백업하세요!
echo.
echo             실행 시 데이터 손실의 위험이 있습니다.
echo.
echo ============================================================
echo.
pause
cls

:: 로그 파일 설정
set LOGFILE=%~dp0disk_partition_script.log
echo [%date% %time%] 스크립트 실행 시작 > %LOGFILE%

:: 간단한 프로그램 설명
echo ============================================================
echo              디스크 파티션 관리 스크립트 v1.0
echo ============================================================
echo.
echo 주요 기능:
echo 1. D 드라이브 데이터 백업, D 드라이브 삭제
echo 2. C 드라이브를 200GB로 확장
echo 2. 남은 공간을 D 드라이브로 생성
echo 3. D 드라이브 데이터 복원
echo.
echo 주의: 실행 전 중요 데이터를 반드시 백업하세요!
echo 로그 파일: %LOGFILE%
echo.
echo 진행하려면 Y, 취소하려면 아무 키나 누르세요.
set /p CONTINUE=입력:
if /i "%CONTINUE%" neq "Y" (
    echo 스크립트를 종료합니다.
    exit /b
)

:SHOW_PARTITIONS
cls
echo ============================================================
echo                 1단계: 디스크 파티션 상태 확인
echo ============================================================
echo.
echo 볼륨 리스트:
echo select disk 0 > diskpart_script.txt
echo list volume >> diskpart_script.txt
diskpart /s diskpart_script.txt
del diskpart_script.txt

:DELETE_PARTITIONS
echo.
echo ============================================================
echo                 2단계: 파티션 삭제 (선택사항)
echo ============================================================
echo.
echo.
echo C 파티션 뒤에 다른 파티션이 있다면 삭제 합니다. (복구 파티션등...)
echo.
set /p DELETE_PARTITIONS=삭제할 파티션 번호 입력 (여러 개는 쉼표로 구분, s=Skip): 
if /i "%DELETE_PARTITIONS%"=="s" (
    echo 파티션 삭제를 건너뜁니다.
    echo [%date% %time%] 사용자가 파티션 삭제를 건너뜀 >> %LOGFILE%
) else (
    for %%i in (%DELETE_PARTITIONS%) do (
        echo 파티션 %%i 삭제 중...
        echo select disk 0 > diskpart_script.txt
        echo select partition %%i >> diskpart_script.txt
        echo delete partition override >> diskpart_script.txt
        diskpart /s diskpart_script.txt >> %LOGFILE% 2>&1
        del diskpart_script.txt
    )
)

:BACKUP_D
cls
echo ============================================================
echo                 3단계: D 드라이브 백업
echo ============================================================
echo.
echo D 드라이브를 C:\D_Backup으로 복사 중...
robocopy D:\ C:\D_Backup /E /COPYALL /R:1 /W:1 /XD "D:\System Volume Information" /XJ /TEE /LOG+:%LOGFILE%

pause

:DELETE_D
cls
echo ============================================================
echo                 4단계: D 드라이브 삭제
echo ============================================================
echo.
echo D 드라이브 삭제 중...
echo select volume D > diskpart_script.txt
echo delete volume >> diskpart_script.txt
diskpart /s diskpart_script.txt >> %LOGFILE% 2>&1
del diskpart_script.txt

:EXTEND_C
cls
echo ============================================================
echo                 5단계: C 드라이브 확장
echo ============================================================
echo.

:: C 드라이브 현재 크기 확인 (MB 단위)
for /f "tokens=*" %%i in ('powershell -command "$size = (Get-WmiObject Win32_LogicalDisk -Filter 'DeviceID=''C:''').Size; [math]::Floor($size/1MB)"') do set C_SIZE_MB=%%i

echo 현재 C 드라이브 크기: %C_SIZE_MB% MB

:: 확장할 크기 계산
set /a SIZE_TO_EXTEND=204800-C_SIZE_MB

if %SIZE_TO_EXTEND% gtr 0 (
    echo C 드라이브를 %SIZE_TO_EXTEND% MB 만큼 확장 중...
    echo select volume C > diskpart_script.txt
    echo extend size=%SIZE_TO_EXTEND% >> diskpart_script.txt
    diskpart /s diskpart_script.txt >> %LOGFILE% 2>&1
    del diskpart_script.txt
) else (
    echo C 드라이브가 이미 200GB 이상입니다. 확장이 필요하지 않습니다.
)

:: 확장 후 크기 확인
for /f "tokens=*" %%i in ('powershell -command "$size = (Get-WmiObject Win32_LogicalDisk -Filter 'DeviceID=''C:''').Size; [math]::Floor($size/1MB)"') do set NEW_C_SIZE_MB=%%i

echo 확장 후 C 드라이브 크기: %NEW_C_SIZE_MB% MB

pause

:CREATE_D
cls
echo ============================================================
echo                 6단계: 새 D 드라이브 생성
echo ============================================================
echo.
echo 새 D 드라이브 생성 중...
echo select disk 0 > diskpart_script.txt
echo create partition primary >> diskpart_script.txt
echo assign letter=D >> diskpart_script.txt
echo format fs=ntfs quick label="Data" >> diskpart_script.txt
diskpart /s diskpart_script.txt >> %LOGFILE% 2>&1
del diskpart_script.txt

:RESTORE_DATA
cls
echo ============================================================
echo                 7단계: 데이터 복원
echo ============================================================
echo.
echo C:\D_Backup의 데이터를 새 D 드라이브로 복원 중...
robocopy C:\D_Backup D:\ /E /COPYALL /R:1 /W:1 /TEE /LOG+:%LOGFILE%

echo.
echo 탐색기에서 D 드라이브를 열어 복원된 파일을 확인하세요.
explorer D:\

pause

:CLEANUP
cls
echo ============================================================
echo                 8단계: 정리 및 완료
echo ============================================================
echo.
set /p VERIFY_RESTORE=복원된 데이터가 정상적인가요?  C:\D_Backup 백업 데이터를 삭제합니다. (Y/N): 
if /i "%VERIFY_RESTORE%"=="Y" (
    echo 백업 데이터 삭제 중...
    rmdir /s /q C:\D_Backup
    echo 백업 데이터가 삭제되었습니다.
) else (
    echo 백업 데이터를 C:\D_Backup에 유지합니다. 수동으로 확인 후 삭제하세요.
)

echo.
echo 모든 작업이 완료되었습니다. 시스템을 재부팅하는 것이 좋습니다.
echo [%date% %time%] 스크립트 실행 완료 >> %LOGFILE%
echo 로그 파일 위치: %LOGFILE%

start /b "" cmd /c del "%~f0"&exit /b


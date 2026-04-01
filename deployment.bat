@echo off
setlocal enabledelayedexpansion

:: start timer for deployment
for /f "tokens=1-4 delims=:.," %%a in ("%time%") do (
    set /a h=1%%a-100
    set /a m=1%%b-100
    set /a s=1%%c-100
    set /a START_SEC=(h*3600)+(m*60)+s
)

:: console colors (limited in cmd)
set BLUE=0x1F
set RESET=0x07

:: helper function for info messages
:info
echo [INFO] %*
goto :eof

:: parameters
set GO_VERSION=1.22.5
set RUNTIME_DIR=.runtime
set GO_DIR=%RUNTIME_DIR%\go
set GO_BIN=%GO_DIR%\bin\go.exe
set GO_FILE=.\src

:: detect platform
ver | findStr /i "windows" >nul
if errorLevel 1 (
    echo Unsupported OS
    exit /b 1
)

:: detect architecture
set ARCH=x86_64
if defined PROCESSOR_ARCHITECTURE (
    if "%PROCESSOR_ARCHITECTURE%"=="AMD64" set ARCH=amd64
    if "%PROCESSOR_ARCHITECTURE%"=="ARM64" set ARCH=arm64
)

:: download Go
if not exist "%GO_BIN%" (
    if not exist "%RUNTIME_DIR%" mkdir "%RUNTIME_DIR%"
    set TAR_FILE=%RUNTIME_DIR%\go.zip
    set GO_URL=https://go.dev/dl/go%GO_VERSION%.windows-%ARCH%.zip
    call :info "Downloading Go %GO_VERSION% for windows/%ARCH%"

    :: use powershell to download
    powershell -Command "Invoke-WebRequest -Uri '%GO_URL%' -OutFile '%TAR_FILE%'"

    call :info "Extracting Go runtime"
    powershell -Command "Expand-Archive -Path '%TAR_FILE%' -DestinationPath '%RUNTIME_DIR%' -Force"

    del "%TAR_FILE%"
)

:: run Go
if exist "%GO_BIN%" (
    call :info "Running Go file using local runtime"
    "%GO_BIN%" run "%GO_FILE%" %*
) else (
    where go >nul 2>nul
    if %errorLevel%==0 (
        call :info "Running Go file using system Go"
        go run "%GO_FILE%" %*
    ) else (
        echo Go not found
        exit /b 1
    )
)

:: calculate runtime
for /f "tokens=1-4 delims=:.," %%a in ("%time%") do (
    set /a h=1%%a-100
    set /a m=1%%b-100
    set /a s=1%%c-100
    set /a START_SEC=(h*3600)+(m*60)+s
)
set /a RUNTIME=%END_SEC% - %START_SEC%
echo Done: executing command in %RUNTIME% seconds

endlocal
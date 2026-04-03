@echo off
setlocal enabledelayedexpansion

:: start timer for deployment
set ROOT_PROCESS_START_TIME=%TIME%

:: setting constants
set RUNTIME_DIR=.runtime
set GO_DIR=%RUNTIME_DIR%\go
set GO_BIN=%GO_DIR%\bin\go.exe
set GO_FILE=.\src

set GO_MOD_FILE=go.mod
set GO_MODULE=module deployment
set GO_VERSION=1.25.1

set DEPLOYMENT_ENV=RUBRION_DEPLOYMENT_DIR

:: check for usage
if "%~1"=="" (
    echo [x] Wrong usage: deployment ^<command^> [args...]
    exit /b 1
)

:: check for install command
if "%~1"=="install" (
    call :install_deployment
    if not exist "%GO_DIR%" (
        where go >nul 2>&1
        if errorlevel 1 (
            call :download_go
        )
    )
    exit /b 0
)

:: check if installed
if not defined %DEPLOYMENT_ENV% (
    echo [x] Deployment could not be found: Environment variable %DEPLOYMENT_ENV% is not set.
    exit /b 1
)

:: check for system go
where go >nul 2>&1
if %ERRORLEVEL%==0 (
    echo  =^> Found system Go
    call :run_go go %*
    goto :end
)

:: check for local go runtime
if exist "%GO_BIN%" (
    echo  =^> Found local runtime Go
    call :run_go "%GO_BIN%" %*
    goto :end
)

:: install and run local go runtime
echo  =^> Go not found. Installing runtime...
call :download_go
call :run_go "%GO_BIN%" %*

:end
:: calculate runtime of root process after command finishes
call :calc_runtime %ROOT_PROCESS_START_TIME% ROOT_PROCESS_RUNTIME
echo [*] Done: executing command in %ROOT_PROCESS_RUNTIME%s
exit /b 0

:install_deployment
    :: start timer for install_deployment
    set INSTALL_PROCESS_START_TIME=%TIME%
    echo [+] Installing Deployment...

    :: check for fitting go.mod
    if not exist "%GO_MOD_FILE%" (
        echo [x] Install command can only be executed in the deployment folder
        exit /b 1
    )

    set /p FIRST_LINE=<"%GO_MOD_FILE%"
    :: strip carriage return from CRLF line endings
    set "FIRST_LINE=%FIRST_LINE:\r=%"
    for /f "delims=" %%A in ("%FIRST_LINE%") do set "FIRST_LINE=%%A"
    if not "%FIRST_LINE%"=="%GO_MODULE%" (
        echo [x] Install command can only be executed in the deployment folder
        exit /b 1
    )

    :: set deployment dir (dp0 already includes trailing backslash)
    set "WORKSPACE_DIR=%~dp0"
    :: remove trailing backslash
    if "%WORKSPACE_DIR:~-1%"=="\" set "WORKSPACE_DIR=%WORKSPACE_DIR:~0,-1%"

    echo  =^> Setting %DEPLOYMENT_ENV%=%WORKSPACE_DIR%

    :: set environment variable permanently for current user
    setx "%DEPLOYMENT_ENV%" "%WORKSPACE_DIR%"
    if %ERRORLEVEL% neq 0 (
        echo [x] Failed to set environment variable
        exit /b 1
    )

    :: set for current session as well
    set "%DEPLOYMENT_ENV%=%WORKSPACE_DIR%"

    echo  =^> [i] Please restart your shell or open a new terminal window for the variable to take effect.

    :: check kubectl
    echo  =^> Checking for kubectl
    where kubectl >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo [x] kubectl not installed
        exit /b 1
    )
    echo  =^> Found kubectl

    :: calculate runtime of install process after command finishes
    call :calc_runtime %INSTALL_PROCESS_START_TIME% INSTALL_PROCESS_RUNTIME
    echo [*] Done: installed Deployment in %INSTALL_PROCESS_RUNTIME%s
    exit /b 0


:download_go
    :: start timer for download_go
    set GO_DOWNLOAD_PROCESS_START_TIME=%TIME%
    echo [+] Downloading Go...

    :: detect architecture
    if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
        set ARCH=amd64
    ) else if "%PROCESSOR_ARCHITEW6432%"=="AMD64" (
        set ARCH=amd64
    ) else if "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
        set ARCH=arm64
    ) else (
        echo [x] Unsupported architecture: %PROCESSOR_ARCHITECTURE%
        exit /b 1
    )

    :: windows only
    set OS=windows

    if not exist "%RUNTIME_DIR%" mkdir "%RUNTIME_DIR%"

    set ZIP_FILE=%RUNTIME_DIR%\go.zip
    set GO_URL=https://go.dev/dl/go%GO_VERSION%.%OS%-%ARCH%.zip

    echo  =^> Downloading Go %GO_VERSION% for %OS%/%ARCH%

    :: download via curl (available on Windows 10+)
    where curl >nul 2>&1
    if %ERRORLEVEL%==0 (
        curl -L "%GO_URL%" -o "%ZIP_FILE%"
    ) else (
        :: fallback to PowerShell
        powershell -Command "Invoke-WebRequest -Uri '%GO_URL%' -OutFile '%ZIP_FILE%'"
    )

    echo  =^> Extracting Go runtime

    :: remove old go dir if present
    if exist "%GO_DIR%" rmdir /s /q "%GO_DIR%"

    :: extract zip using PowerShell
    powershell -Command "Expand-Archive -Path '%ZIP_FILE%' -DestinationPath '%RUNTIME_DIR%' -Force"

    :: clean up zip
    del "%ZIP_FILE%"

    :: calculate runtime of download_go process after command finishes
    call :calc_runtime %GO_DOWNLOAD_PROCESS_START_TIME% GO_DOWNLOAD_PROCESS_RUNTIME
    echo [*] Done: installed Go in %GO_DOWNLOAD_PROCESS_RUNTIME%s
    exit /b 0


:run_go
    :: run the go file with the given executable
    set GO_EXEC=%~1
    shift
    echo  =^> Running Go file using: %GO_EXEC%
    "%GO_EXEC%" run "%GO_FILE%" %*
    exit /b %ERRORLEVEL%


:calc_runtime
    :: simple runtime calculation in seconds (best-effort, wraps at midnight)
    set START=%~1
    set RESULT_VAR=%~2

    :: parse start time HH:MM:SS,xx
    for /f "tokens=1-4 delims=:.," %%a in ("%START%") do (
        set /a START_S = %%a*3600 + %%b*60 + %%c
    )

    :: parse current time
    for /f "tokens=1-4 delims=:.," %%a in ("%TIME%") do (
        set /a END_S = %%a*3600 + %%b*60 + %%c
    )

    set /a %RESULT_VAR% = END_S - START_S
    exit /b 0
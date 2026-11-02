@echo off
rem ===========================================================================
rem  WorkBuddy Token Monitor - Windows launcher
rem
rem  run-win.bat              open the native desktop panel
rem  run-win.bat --web        serve the web panel and open the browser
rem  run-win.bat --stop       stop the web panel service
rem  run-win.bat --console    run in this console window (for debugging)
rem  run-win.bat --range 7d   extra arguments are passed to qt_app.py
rem
rem  Needs Python 3.8+ on PATH. PyQt5 is installed automatically on first run.
rem  The virtual env lives outside this folder on purpose: Qt5 fails to load
rem  from a path that contains non-ASCII characters (see README_windows.md).
rem ===========================================================================
setlocal EnableExtensions EnableDelayedExpansion
title WorkBuddy Token Monitor

set "REPO=%~dp0"
set "VENV=%LOCALAPPDATA%\WorkBuddyTokenMonitor\venv"
set "PYEXE=%VENV%\Scripts\python.exe"
set "PYWEXE=%VENV%\Scripts\pythonw.exe"
set "RUNTIME=%REPO%.runtime"
set "PORT=8791"
if defined WB_MONITOR_PORT set "PORT=%WB_MONITOR_PORT%"
if not exist "%RUNTIME%" mkdir "%RUNTIME%" >nul 2>&1

if /i "%~1"=="--stop" goto :stop

rem --------------------------------------------------------------- python
set "PY="
where python >nul 2>&1
if not errorlevel 1 (
    python -c "import sys;sys.exit(0 if sys.version_info>=(3,8) else 1)" >nul 2>&1
    if not errorlevel 1 set "PY=python"
)
if not defined PY (
    where py >nul 2>&1
    if not errorlevel 1 (
        py -3 -c "import sys;sys.exit(0 if sys.version_info>=(3,8) else 1)" >nul 2>&1
        if not errorlevel 1 set "PY=py -3"
    )
)
if not defined PY (
    if exist "%USERPROFILE%\.workbuddy\binaries\python\versions\current\python.exe" (
        set "PY=%USERPROFILE%\.workbuddy\binaries\python\versions\current\python.exe"
    )
)
if not defined PY goto :nopython

rem --------------------------------------------------------------- venv
if not exist "%PYEXE%" (
    echo [1/2] Creating Python environment ...
    echo       %VENV%
    %PY% -m venv "%VENV%"
    if errorlevel 1 goto :venvfail
)

if /i "%~1"=="--web" goto :web

rem --------------------------------------------------------------- PyQt5
"%PYEXE%" -c "import PyQt5.QtWidgets" >nul 2>&1
if not errorlevel 1 goto :launch
echo [2/2] Installing PyQt5, about 60 MB, first run only ...
call :pipTry https://mirrors.aliyun.com/pypi/simple
if errorlevel 1 call :pipTry https://pypi.tuna.tsinghua.edu.cn/simple
if errorlevel 1 call :pipTry https://pypi.org/simple
"%PYEXE%" -c "import PyQt5.QtWidgets" >nul 2>&1
if errorlevel 1 goto :noqt

:launch
set "FWD=%*"
if defined FWD set "FWD=!FWD:--console=!"
if /i "%~1"=="--console" (
    "%PYEXE%" "%REPO%qt_app.py" !FWD!
    exit /b !errorlevel!
)
start "" "%PYWEXE%" "%REPO%qt_app.py" !FWD!
exit /b 0

:pipTry
"%PYEXE%" -m pip install --disable-pip-version-check --no-input --prefer-binary --retries 5 --timeout 60 -i %~1 PyQt5
exit /b %errorlevel%

rem --------------------------------------------------------------- web mode
:web
echo [web] starting server on port %PORT% ...
start "" /b cmd /c ""%PYEXE%" "%REPO%server.py" --port %PORT% > "%RUNTIME%\server-win.log" 2>&1"
where curl >nul 2>&1
if errorlevel 1 (
    timeout /t 3 /nobreak >nul
    start "" "http://127.0.0.1:%PORT%"
    echo [web] panel: http://127.0.0.1:%PORT%
    exit /b 0
)
set "OK="
set /a TRY=0
:webwait
set /a TRY+=1
curl -s --max-time 1 "http://127.0.0.1:%PORT%/api/ping" | findstr /c:"ok" >nul && set "OK=1"
if defined OK goto :webopen
if !TRY! lss 30 (
    timeout /t 1 /nobreak >nul
    goto :webwait
)
echo [!] the server did not answer, see "%RUNTIME%\server-win.log"
pause
exit /b 1
:webopen
start "" "http://127.0.0.1:%PORT%"
echo [web] panel: http://127.0.0.1:%PORT%
echo [web] stop it with: run-win.bat --stop
exit /b 0

rem --------------------------------------------------------------- stop
:stop
echo [stop] looking for a listener on port %PORT% ...
set "FOUND="
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /r /c:":%PORT% .*LISTENING"') do (
    taskkill /f /pid %%P >nul 2>&1 && set "FOUND=1"
)
if defined FOUND (echo [stop] done.) else (echo [stop] nothing is listening on port %PORT%.)
exit /b 0

rem --------------------------------------------------------------- errors
:nopython
echo [!] Python 3.8+ was not found on this machine.
echo     Install it from https://www.python.org/downloads/
echo     and tick "Add python.exe to PATH" during setup.
pause
exit /b 1

:venvfail
echo [!] Could not create the Python environment at
echo     %VENV%
echo     Make sure this path contains ASCII characters only.
pause
exit /b 1

:noqt
echo [!] PyQt5 could not be installed, so the native window is unavailable.
echo     Falling back to the web panel. If PyPI is blocked, set a proxy or
echo     a mirror in pip.ini and try again.
goto :web

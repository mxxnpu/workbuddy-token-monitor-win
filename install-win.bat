@echo off
rem ===========================================================================
rem  WorkBuddy Token Monitor - one-file Windows installer
rem
rem  Double-click this file. It will:
rem    1. locate Python 3.8+
rem    2. take the source from the folder this file sits in, or download it
rem    3. install everything under %LOCALAPPDATA%\WorkBuddyTokenMonitor
rem    4. create the virtual env and install PyQt5
rem    5. drop a desktop shortcut and start the panel
rem
rem  Options:
rem    --no-shortcut   do not create the desktop shortcut
rem    --no-run        install only, do not start the panel
rem    --web           start the web panel instead of the native window
rem
rem  Everything is installed to an ASCII path on purpose: Qt5 refuses to load
rem  from a path that contains non-ASCII characters. See README_windows.md.
rem ===========================================================================
setlocal EnableExtensions EnableDelayedExpansion
title WorkBuddy Token Monitor - Setup

set "ROOT=%LOCALAPPDATA%\WorkBuddyTokenMonitor"
set "APP=%ROOT%\app"
set "VENV=%ROOT%\venv"
set "PYEXE=%VENV%\Scripts\python.exe"
set "PYWEXE=%VENV%\Scripts\pythonw.exe"
set "TMPZIP=%TEMP%\wbtm-src.zip"
set "TMPDIR=%TEMP%\wbtm-src"
set "ZIPURL=https://codeload.github.com/mxxnpu/workbuddy-token-monitor-win/zip/refs/heads/main"
set "ZIPURL2=https://github.com/mxxnpu/workbuddy-token-monitor-win/archive/refs/heads/main.zip"
set "PATCH=%TEMP%\wbtm-fontpatch.py"
set "WANT_SHORTCUT=1"
set "WANT_RUN=1"
set "MODE=gui"

:parse
if /i "%~1"=="--no-shortcut" (set "WANT_SHORTCUT=0" & shift & goto :parse)
if /i "%~1"=="--no-run" (set "WANT_RUN=0" & shift & goto :parse)
if /i "%~1"=="--web" (set "MODE=web" & shift & goto :parse)
if /i "%~1"=="--help" goto :help
if /i "%~1"=="-h" goto :help

echo.
echo   WorkBuddy Token Monitor - Windows setup
echo   ======================================
echo   install dir : %ROOT%
echo.

rem --------------------------------------------------------------- [1/5] python
echo [1/5] looking for Python 3.8+ ...
set "PY="
where python >nul 2>&1
if errorlevel 1 goto :py2
python -c "import sys;sys.exit(0 if sys.version_info>=(3,8) else 1)" >nul 2>&1
if errorlevel 1 goto :py2
set "PY=python"
goto :pydone

:py2
where py >nul 2>&1
if errorlevel 1 goto :py3
py -3 -c "import sys;sys.exit(0 if sys.version_info>=(3,8) else 1)" >nul 2>&1
if errorlevel 1 goto :py3
set "PY=py -3"
goto :pydone

:py3
if exist "%USERPROFILE%\.workbuddy\binaries\python\versions\current\python.exe" set "PY=%USERPROFILE%\.workbuddy\binaries\python\versions\current\python.exe"
if not defined PY goto :nopython

:pydone
%PY% -V
echo       ok

rem --------------------------------------------------------------- [2/5] source
echo.
if exist "%~dp0qt_app.py" goto :local
echo [2/5] downloading source ...
if exist "%TMPZIP%" del /q "%TMPZIP%" >nul 2>&1
where curl >nul 2>&1
if errorlevel 1 goto :psdownload
curl -fL --retry 3 --connect-timeout 20 -o "%TMPZIP%" "%ZIPURL%" >nul 2>&1
if errorlevel 1 curl -fL --retry 3 --connect-timeout 20 -o "%TMPZIP%" "%ZIPURL2%" >nul 2>&1
goto :checkzip

:psdownload
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%ZIPURL%' -OutFile '%TMPZIP%' -UseBasicParsing } catch { exit 1 }"
if errorlevel 1 powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%ZIPURL2%' -OutFile '%TMPZIP%' -UseBasicParsing } catch { exit 1 }"

:checkzip
if not exist "%TMPZIP%" goto :dlfail
for %%A in ("%TMPZIP%") do if %%~zA LSS 20000 goto :dlfail
if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%" >nul 2>&1
rem use the system bsdtar, which understands zip; a bare "tar" from PATH
rem may be GNU tar and would fail on a zip archive
set "TAREXE="
if exist "%SystemRoot%\System32\tar.exe" set "TAREXE=%SystemRoot%\System32\tar.exe"
if not defined TAREXE goto :psunzip
"%TAREXE%" -xf "%TMPZIP%" -C "%TEMP%" >nul 2>&1
if not exist "%TEMP%\workbuddy-token-monitor-win-main" goto :psunzip
move "%TEMP%\workbuddy-token-monitor-win-main" "%TMPDIR%" >nul 2>&1
goto :srcdone

:psunzip
powershell -NoProfile -Command "try { Expand-Archive -LiteralPath '%TMPZIP%' -DestinationPath '%TMPDIR%' -Force } catch { exit 1 }"
if exist "%TMPDIR%\workbuddy-token-monitor-win-main" set "TMPDIR=%TMPDIR%\workbuddy-token-monitor-win-main"
goto :srcdone

:local
echo [2/5] using the source next to this file
set "TMPDIR=%~dp0"
set "TMPDIR=%TMPDIR:~0,-1%"
goto :copysrc

:srcdone
if not exist "%TMPDIR%\qt_app.py" goto :dlfail
echo       ok

rem --------------------------------------------------------------- [3/5] files
:copysrc
echo.
echo [3/5] installing files to %APP% ...
echo       source: %TMPDIR%
if not exist "%APP%" mkdir "%APP%" >nul 2>&1
robocopy "%TMPDIR%" "%APP%" /E /XD .git .runtime .venv __pycache__ /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 goto :copyfail
echo       ok

rem --------------------------------------------------------------- [4/5] venv
echo.
echo [4/5] preparing Python environment ...
if not exist "%PYEXE%" goto :mkvenv
echo       reusing %VENV%
goto :deps

:mkvenv
%PY% -m venv "%VENV%"
if errorlevel 1 goto :venvfail
echo       created %VENV%

:deps
"%PYEXE%" -c "import PyQt5.QtWidgets" >nul 2>&1
if not errorlevel 1 goto :deps_ok
echo       installing PyQt5, about 60 MB, please wait ...
"%PYEXE%" -m pip install --disable-pip-version-check --no-input --prefer-binary --retries 5 --timeout 60 -i https://mirrors.aliyun.com/pypi/simple PyQt5
if errorlevel 1 "%PYEXE%" -m pip install --disable-pip-version-check --no-input --prefer-binary --retries 5 --timeout 60 -i https://pypi.tuna.tsinghua.edu.cn/simple PyQt5
if errorlevel 1 "%PYEXE%" -m pip install --disable-pip-version-check --no-input --prefer-binary --retries 5 --timeout 60 -i https://pypi.org/simple PyQt5
"%PYEXE%" -c "import PyQt5.QtWidgets" >nul 2>&1
if errorlevel 1 goto :noqt

:deps_ok
echo       ok

rem --------------------------------------------------------------- font fix
rem  Upstream hardcodes the Linux fonts "Droid Sans Fallback" / "DejaVu Sans".
rem  Windows has neither, so Qt silently falls back to SimSun (a thin serif).
rem  Newer source already carries the fix; only patch older copies.
findstr /c:"_FONT_CANDIDATES" "%APP%\qt_app.py" >nul 2>&1
if not errorlevel 1 goto :fontdone
echo       applying font fallback patch ...
call :writePatch
"%PYEXE%" "%PATCH%" "%APP%\qt_app.py"
:fontdone

rem --------------------------------------------------------------- [5/5] shortcut
echo.
if "%WANT_SHORTCUT%"=="0" goto :launch
echo [5/5] creating desktop shortcut ...
if exist "%APP%\run-win.bat" goto :lnkB
set "LNK_TARGET=%PYWEXE%"
set "LNK_ARGS="%APP%\qt_app.py""
goto :lnkgo
:lnkB
set "LNK_TARGET=%APP%\run-win.bat"
set "LNK_ARGS="
:lnkgo
powershell -NoProfile -Command "$w=New-Object -ComObject WScript.Shell; $s=$w.CreateShortcut([Environment]::GetFolderPath('Desktop')+'\WorkBuddy Token Monitor.lnk'); $s.TargetPath='%LNK_TARGET%'; $s.Arguments='%LNK_ARGS%'; $s.WorkingDirectory='%APP%'; $s.Description='WorkBuddy usage monitor'; $s.Save()"
if errorlevel 1 goto :lnkfail
echo       ok
goto :launch

:lnkfail
echo       [!] shortcut not created, run "%APP%\qt_app.py" directly instead

rem --------------------------------------------------------------- run
:launch
echo.
if "%WANT_RUN%"=="0" goto :done
if /i "%MODE%"=="web" goto :runweb
echo starting the panel ...
start "" "%PYWEXE%" "%APP%\qt_app.py"
goto :done

:runweb
echo starting the web panel on port 8791 ...
start "" /b cmd /c ""%PYEXE%" "%APP%\server.py" --port 8791 > "%APP%\.runtime\server-win.log" 2>&1"
echo open http://127.0.0.1:8791 in your browser

:done
echo.
echo   Done. Installed at %ROOT%
echo   Re-run this file any time to update or repair.
echo.
if "%WANT_RUN%"=="0" pause
exit /b 0

rem --------------------------------------------------------------- helpers
:writePatch
> "%PATCH%" echo import io, sys
>>"%PATCH%" echo p = sys.argv[1]
>>"%PATCH%" echo s = io.open(p, encoding="utf-8").read()
>>"%PATCH%" echo if "Noto Sans SC" in s:
>>"%PATCH%" echo     print("       already patched")
>>"%PATCH%" echo     sys.exit(0)
>>"%PATCH%" echo s = s.replace('QFont("Droid Sans Fallback")', 'QFont("Noto Sans SC")')
>>"%PATCH%" echo s = s.replace('QFont("DejaVu Sans")', 'QFont("Noto Sans SC")')
>>"%PATCH%" echo s = s.replace("f.setWeight(weight)", "f.setWeight(QFont.Medium if weight == QFont.Normal else weight)")
>>"%PATCH%" echo io.open(p, "w", encoding="utf-8").write(s)
>>"%PATCH%" echo print("       patched")
exit /b 0

rem --------------------------------------------------------------- errors
:help
echo.
echo   run:  install-win.bat [--no-shortcut] [--no-run] [--web]
echo.
pause
exit /b 0

:nopython
echo [!] Python 3.8+ was not found.
echo     Install it from https://www.python.org/downloads/
echo     and tick "Add python.exe to PATH" during setup.
pause
exit /b 1

:dlfail
echo [!] Could not download the source.
echo     Download the repository zip manually and unpack it, then put this
echo     file next to qt_app.py and run it again.
pause
exit /b 1

:copyfail
echo [!] Could not copy the files to %APP%
echo     Close any running copy of the panel and try again.
pause
exit /b 1

:venvfail
echo [!] Could not create the virtual environment at
echo     %VENV%
echo     Make sure this path contains ASCII characters only.
pause
exit /b 1

:noqt
echo [!] PyQt5 could not be installed, the native window is unavailable.
echo     You can still use the web panel: install-win.bat --web --no-shortcut
pause
exit /b 1

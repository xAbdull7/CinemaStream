@echo off
setlocal enabledelayedexpansion

echo =========================================================
echo       CinemaStream - Windows Release & Setup Builder
echo =========================================================
echo.

cd /d "%~dp0\.."

echo [1/3] Building Flutter Windows Release...
call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Flutter build failed!
    exit /b %ERRORLEVEL%
)

echo.
echo [2/3] Compiling Standalone Setup with Inno Setup 6...
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    set "ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
) else (
    set "ISCC=ISCC.exe"
)

"%ISCC%" "installer\cinemastream_setup.iss"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Inno Setup compilation failed!
    exit /b %ERRORLEVEL%
)

echo.
echo [3/3] Build completed successfully!
echo Setup file located at: installer\output\CinemaStream_Setup_v1.0.0.exe
echo.
pause


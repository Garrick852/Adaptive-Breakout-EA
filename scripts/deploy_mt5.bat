@echo off
setlocal

REM ============================================================
REM  Deploy packaged EA to MetaTrader 5 Data Folder
REM  - Copies from dist/mt5/MQL5/... to MT5 Data Folder
REM  - Preserves folder structure (Experts, Include, Files)
REM  - Automates deployment for CI/CD integration
REM ============================================================

REM === Configuration ===
set MT5_DATA=%APPDATA%\MetaQuotes\Terminal\43A9BD896CCB6BF2DF5C71EA198AE39D\MQL5
set DIST=dist\mt5\MQL5

REM === Run packaging script ===
echo 📦 Packaging MT5 files...
python scripts\package_mt5.py
if %ERRORLEVEL% neq 0 (
    echo ❌ Packaging failed!
    exit /b 1
)

REM === Copy to MT5 Data Folder ===
echo 🚀 Deploying to Ultima Markets MT5...

xcopy /E /Y "%DIST%\Experts" "%MT5_DATA%\Experts"
xcopy /E /Y "%DIST%\Include" "%MT5_DATA%\Include"
xcopy /E /Y "%DIST%\Files"   "%MT5_DATA%\Files"

echo ✅ Deployment complete. Refresh Expert Advisors in MT5.
pause
endlocal

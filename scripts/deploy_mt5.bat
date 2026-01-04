@echo off
setlocal

REM === Configuration ===
set MT5_DATA=C:\Users\User\AppData\Roaming\MetaQuotes\Terminal\43A9BD896CCB6BF2DF5C71EA198AE39D
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

xcopy /E /I /Y "%DIST%\Experts\AdaptiveBreakoutAI" "%MT5_DATA%\MQL5\Experts\Advisors\AdaptiveBreakoutAI"
xcopy /E /I /Y "%DIST%\Include\AdaptiveBreakoutAI" "%MT5_DATA%\MQL5\Include\AdaptiveBreakoutAI"
xcopy /E /I /Y "%DIST%\Files\configs" "%MT5_DATA%\MQL5\Files\configs"
xcopy /E /I /Y "%DIST%\Files\dashboards" "%MT5_DATA%\MQL5\Files\dashboards"

echo ✅ Deployment complete! Refresh Expert Advisors in MT5.
endlocal

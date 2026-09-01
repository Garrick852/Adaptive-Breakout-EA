@echo off
REM Deploy packaged EA to MetaTrader 5 Data Folder
REM PILOT TARGET (2026-09): installed MetaTrader 5 terminal = clean-slate demo.
REM Operator MUST log in a NEW demo account (not 801027 / 801001 / 1514183711)
REM before attaching the EA. See docs/PILOT_RUN_CHECKLIST.md.

set MT5_DATA=C:\Users\User\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5
set DIST=dist\mt5_package\MQL5

echo Deploying EA package...
xcopy /E /Y "%DIST%\Experts" "%MT5_DATA%\Experts"
xcopy /E /Y "%DIST%\Include" "%MT5_DATA%\Include"
xcopy /E /Y "%DIST%\Files"   "%MT5_DATA%\Files"

echo ✅ Deployment complete.
pause
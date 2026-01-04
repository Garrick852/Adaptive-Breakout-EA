@echo off
REM Deploy packaged EA to MetaTrader 5 Data Folder

set MT5_DATA=C:\Users\User\AppData\Roaming\MetaQuotes\Terminal\43A9BD896CCB6BF2DF5C71EA198AE39D\MQL5
set DIST=dist\mt5\MQL5

echo Deploying EA package...
xcopy /E /Y "%DIST%\Experts" "%MT5_DATA%\Experts"
xcopy /E /Y "%DIST%\Include" "%MT5_DATA%\Include"
xcopy /E /Y "%DIST%\Files"   "%MT5_DATA%\Files"

echo ✅ Deployment complete.
pause
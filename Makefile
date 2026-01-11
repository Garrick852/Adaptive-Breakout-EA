# Makefile for AdaptiveBreakoutAI EA
# Local build and package workflow (MQL5 only)

MT5_DIR = "C:/Program Files/MetaTrader 5"
SRC     = eas/AdaptiveBreakoutAI/src/AdaptiveBreakoutAI.mq5
BIN     = eas/AdaptiveBreakoutAI/src/AdaptiveBreakoutAI.ex5
LOG     = logs/build.log
DIST    = dist/mt5

.PHONY: all build package clean

all: build package

## Compile the EA using MetaEditor
build:
    @echo "Compiling EA..."
    @if exist $(MT5_DIR)/MetaEditor64.exe ( \
        "$(MT5_DIR)/MetaEditor64.exe" /compile:$(SRC) /log:$(LOG) \
    ) else if exist $(MT5_DIR)/MetaEditor.exe ( \
        "$(MT5_DIR)/MetaEditor.exe" /compile:$(SRC) /log:$(LOG) \
    ) else ( \
        echo "MetaEditor not found in $(MT5_DIR)" && exit 1 \
    )
    @if not exist $(BIN) ( \
        echo "Build failed — $(BIN) not found. See $(LOG)." && exit 1 \
    )

## Package EA into MQL5 folder structure and zip
package: build
    @echo "Packaging EA..."
    @mkdir $(DIST)/MQL5/Experts 2>nul || true
    @mkdir $(DIST)/MQL5/Include 2>nul || true
    @mkdir $(DIST)/MQL5/Files/configs 2>nul || true
    @mkdir $(DIST)/MQL5/Files/dashboards 2>nul || true
    @mkdir $(DIST)/MQL5/Logs 2>nul || true

    @copy $(BIN) $(DIST)/MQL5/Experts/ >nul
    @copy Include\*.mqh $(DIST)/MQL5/Include\ >nul 2>nul || true
    @copy configs\*.json $(DIST)/MQL5/Files\configs\ >nul 2>nul || true
    @copy dashboards\*.yaml $(DIST)/MQL5/Files\dashboards\ >nul 2>nul || true

    @echo Runtime logs will be generated here. > $(DIST)/MQL5/Logs/.keep

    @powershell -Command "Compress-Archive -Path 'MQL5/*' -DestinationPath 'AdaptiveBreakoutAI-Package.zip' -WorkingDirectory '$(DIST)' -Force"

## Clean build artifacts
clean:
    @echo "Cleaning..."
    @del /Q $(BIN) 2>nul || true
    @del /Q $(LOG) 2>nul || true
    @rmdir /S /Q $(DIST) 2>nul || true

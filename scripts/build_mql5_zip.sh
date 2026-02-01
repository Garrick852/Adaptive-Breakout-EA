#!/bin/bash

# Define the output file name
OUTPUT="mql5_package.zip"

# Create a temporary directory
TMP_DIR=$(mktemp -d)

# Copy EA main file
cp -r path/to/EA_main_file.mq5 "$TMP_DIR/"

# Copy header files
cp -r path/to/header_files/* "$TMP_DIR/"

# Add DLL configuration
cp -r path/to/dll_config/* "$TMP_DIR/"

# Include EA settings
cp -r path/to/EA_settings/* "$TMP_DIR/"

# Include documentation
cp -r path/to/documentation/* "$TMP_DIR/"

# Change directory to temporary directory
cd "$TMP_DIR"

# Package the contents into a ZIP file
zip -r "$OUTPUT" *

# Move the ZIP file to the original directory
mv "$OUTPUT" ..

# Clean up temporary directory
cd ..
rm -rf "$TMP_DIR"

echo "MQL5 scaffolding packaged into $OUTPUT successfully!"
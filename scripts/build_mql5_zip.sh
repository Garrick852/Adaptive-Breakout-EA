#!/bin/bash

# Create a zip file containing all MQL5 files.

# Navigate to the directory where MQL5 files are located
cd /path/to/mql5/files || exit

# Create a zip file
zip -r AdaptiveBreakoutEA_MQL5.zip *.mq5 *.mqh

# Move the zip file to the desired location
mv AdaptiveBreakoutEA_MQL5.zip /path/to/destination/
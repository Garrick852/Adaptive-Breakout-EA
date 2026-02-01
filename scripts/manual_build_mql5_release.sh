#!/bin/bash

# This script generates complete MQL5 scaffolding for the Adaptive Breakout EA

# Define the project directory
PROJECT_DIR="AdaptiveBreakoutEA"

# Create project directory
mkdir -p $PROJECT_DIR

# Create necessary subdirectories
mkdir -p $PROJECT_DIR/{include,src,resources}

# Create MQL5 files
cat <<EOL > $PROJECT_DIR/src/AdaptiveBreakoutEA.mq5
//+------------------------------------------------------------------+
//|                                                       AdaptiveBreakoutEA.mq5 |
//|                        Copyright 2026 Garrick852                    |
//|                                     https://www.example.com/       |
//+------------------------------------------------------------------+

// Expert initialization function
int OnInit()
{
    // Initialization code here
    return INIT_SUCCEEDED;
}

// Expert deinitialization function
void OnDeinit(const int reason)
{
    // Cleanup code here
}

// Expert tick function
void OnTick()
{
    // Trading logic here
}
EOL

# Create a README file
cat <<EOL > $PROJECT_DIR/README.md
# Adaptive Breakout EA

This is an Expert Advisor for MetaTrader 5 that implements the Adaptive Breakout strategy.

## Directory Structure
- include/: Header files
- src/: Source files
- resources/: Additional resources
EOL

# Zip the project
cd $PROJECT_DIR
zip -r ../AdaptiveBreakoutEA_MQL5.zip .

# Move back to original directory
cd ..

echo "MQL5 scaffolding generated and AdaptiveBreakoutEA_MQL5.zip created successfully!"
// CORRECTED

#property copyright "Garrick852"
#property link      "https://github.com/Garrick852/Adaptive-Breakout-EA"
#property version   "1.00"
#property strict

// --- Includes ---
#include "utils.mqh"
#include "volatility.mqh"
#include "risk.mqh"
#include "trade_exec.mqh"
#include "prop_rules.mqh"
#include "strategy_breakout.mqh"
#include "strategy_meanrevert.mqh"
#include "drift_detection.mqh"

// --- Enums and modes ---
// (Your enums here)
enum StrategyMode { MODE_BREAKOUT=0, MODE_MEANREVERT=1, MODE_AUTO=2 };
enum BoxModeInput { BOXMODE_DONCHIAN=0, BOXMODE_TIMERANGE=1 };


// --- Inputs ---
// (All your inputs here)
input bool InpUseSessionFilter = false;
// ... all other inputs

// --- REMOVE GLOBAL OBJECTS ---
// The following lines should be DELETED. Your .mqh files use static methods.
// CUtils               Utils;
// CVolatility          Volatility;
// CRisk                Risk;
// ... etc.

// --- Expert initialization ---
int OnInit()
{
    // Sanity checks...
    if(InpDriftBreakoutRatio <= InpDriftMeanRevRatio) {
        PrintFormat("AdaptiveBreakoutAI: invalid drift thresholds");
    }
    // ... other checks

    // Correct static call
    Drift::Init();
    return(INIT_SUCCEEDED);
}

// ... the rest of your OnTick() function should now work correctly,
// as it was already using the correct static call syntax, like Utils::IsWithinSession(...)

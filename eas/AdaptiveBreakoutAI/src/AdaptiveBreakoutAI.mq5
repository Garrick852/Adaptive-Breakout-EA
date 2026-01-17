// eas/AdaptiveBreakoutAI/src/AdaptiveBreakoutAI.mq5

#property copyright "Garrick852"
#property link      "https://github.com/Garrick852/Adaptive-Breakout-EA"
#property version   "1.00"
#property strict

// --- FIX: INCLUDES MUST BE AT THE TOP ---
// The compiler needs to load these files BEFORE it reads your input variables.
#include "utils.mqh"
#include "volatility.mqh"
#include "risk.mqh"
#include "trade_exec.mqh"
#include "prop_rules.mqh"
#include "strategy_breakout.mqh"
#include "strategy_meanrevert.mqh"
#include "drift_detection.mqh"

//-------------------------------------------------------------------
// Enums and modes
//-------------------------------------------------------------------
enum StrategyMode
{
    MODE_BREAKOUT   = 0,
    MODE_MEANREVERT = 1,
    MODE_AUTO       = 2
};

enum BoxModeInput
{
    BOXMODE_DONCHIAN  = 0,
    BOXMODE_TIMERANGE = 1
};

//-------------------------------------------------------------------
// Inputs (Now declared AFTER the includes)
//-------------------------------------------------------------------
// Session filter
input bool   InpUseSessionFilter    = false;
input int    InpSessionStartHour    = 0;
input int    InpSessionEndHour      = 23;

// Prop rules / daily loss / total DD / cooldown
// This line will now work correctly
input int    InpOperMode            = PropRules::MODE_NORMAL;
input double InpDailyLossStopPct    = 5.0;
input double InpMaxTotalDDPct       = 10.0;
input int    InpMinMinutesBetweenTrades = 5;

// ... (The rest of your inputs and code remain the same) ...

//-------------------------------------------------------------------
// Expert initialization
//-------------------------------------------------------------------
int OnInit()
{
   // ...
   return(INIT_SUCCEEDED);
}

//-------------------------------------------------------------------
// Expert deinitialization
//-------------------------------------------------------------------
void OnDeinit(const int reason)
{
   // ...
}

//-------------------------------------------------------------------
// Expert tick
//-------------------------------------------------------------------
void OnTick()
{
   // ...
}

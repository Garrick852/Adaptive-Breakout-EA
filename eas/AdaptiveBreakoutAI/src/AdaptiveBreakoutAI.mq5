#property copyright "Garrick852"
#property link      "https://github.com/Garrick852/Adaptive-Breakout-EA"
#property version   "1.03" // Version updated for bug fixes
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
enum StrategyMode { MODE_BREAKOUT = 0, MODE_MEANREVERT = 1, MODE_AUTO = 2 };
enum BoxModeInput { BOXMODE_DONCHIAN = 0, BOXMODE_TIMERANGE = 1 };

// --- Inputs ---
// Session filter
input bool   InpUseSessionFilter    = false;
input int    InpSessionStartHour    = 8;
input int    InpSessionEndHour      = 16;

// Prop rules / daily loss / total DD / cooldown
input PropRules::OperationMode InpOperMode = PropRules::MODE_NORMAL;
input double InpDailyLossStopPct    = 5.0;
input double InpMaxTotalDDPct       = 10.0;
input int    InpMinMinutesBetweenTrades = 30;

// Risk
input double InpRiskPercentPerTrade = 1.0;

// Breakout Strategy
input StrategyMode InpStrategyMode         = MODE_AUTO;
input BoxModeInput InpBoxMode              = BOXMODE_DONCHIAN;
input int    InpBreakoutLookback       = 24;     // For Donchian
input int    InpBreakoutTimeFrom       = 0;      // For TimeRange
input int    InpBreakoutTimeTo         = 6;      // For TimeRange
input double InpBreakoutBufferPts      = 10.0;
input bool   InpBreakoutUsePending     = false;
input bool   InpBreakoutRequiresClose  = false; // If true, waits for a candle to close outside the box
input double InpMinAtrFilterPts        = 10.0;  // Minimum ATR value in points

// Mean Reversion Strategy
input int    InpMR_EMAPeriod        = 200;
input double InpMR_ZScoreThresh     = 2.0;

// Shared Strategy SL/TP
input ENUM_TIMEFRAMES InpAtrTimeframe = PERIOD_CURRENT;
input int    InpAtrPeriod           = 14;
input double InpAtrMultSL           = 2.0;
input double InpAtrMultTP           = 3.0;

// Adaptive Logic
input double InpDriftBreakoutRatio  = 1.3;
input double InpDriftMeanRevRatio   = 0.9;

// --- OnInit ---
int OnInit()
{
    Print("AdaptiveBreakoutAI EA Initializing...");
    if(InpDriftBreakoutRatio <= InpDriftMeanRevRatio) {
        PrintFormat("Warning: Invalid drift thresholds (breakout=%.2f, meanrev=%.2f)", InpDriftBreakoutRatio, InpDriftMeanRevRatio);
    }
    Drift::Init();
    Print("EA Initialized Successfully.");
    return(INIT_SUCCEEDED);
}

// --- OnDeinit ---
void OnDeinit(const int reason)
{
    Print("AdaptiveBreakoutAI EA Deinitializing. Reason: ", reason);
}

// --- OnTick ---
void OnTick()
{
    static datetime last_print_time = 0;
    if (TimeCurrent() - last_print_time < 5) return;
    last_print_time = TimeCurrent();
    PrintFormat("--------------------------------------------------");
    PrintFormat("Tick received for %s at %s", _Symbol, TimeToString(TimeCurrent()));

    if (InpUseSessionFilter) {
        if (!Utils::IsWithinSession(InpSessionStartHour, InpSessionEndHour)) {
            PrintFormat("DEBUG: FAIL - Trading session is not active.");
            return;
        }
    }
    Print("DEBUG: PASS - Session check passed.");

    if (!PropRules::AllowTrading(InpOperMode, InpDailyLossStopPct, InpMaxTotalDDPct)) {
        Print("DEBUG: FAIL - Prop rules prevent trading.");
        return;
    }
    Print("DEBUG: PASS - Prop rules check passed.");

    if (!Utils::PassedCooldownMinutes(InpMinMinutesBetweenTrades)) {
        PrintFormat("DEBUG: FAIL - In cooldown period.");
        return;
    }
    Print("DEBUG: PASS - Cooldown check passed.");

    if (Risk::HasOpenPosition(_Symbol)) {
        Print("DEBUG: INFO - Position already open for this symbol. Skipping.");
        return;
    }
    Print("DEBUG: PASS - No open positions for this symbol.");

    // --- Core Logic ---
    ENUM_TIMEFRAMES atr_tf = InpAtrTimeframe == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)Period() : InpAtrTimeframe;
    double atr = Volatility::ATR(_Symbol, atr_tf, InpAtrPeriod);
    PrintFormat("DEBUG: ATR value is %.5f for period %d.", atr, InpAtrPeriod);

    // --- FIX #2: Pass only the ATR value to the Update function ---
    Drift::Update(atr); 

    if (atr <= 0.0) {
        Print("DEBUG: FAIL - ATR is zero or invalid.");
        return;
    }
    Print("DEBUG: PASS - ATR check passed.");

    // --- Strategy Selection ---
    StrategyMode mode_to_run = InpStrategyMode;
    if(InpStrategyMode == MODE_AUTO) {
        int driftSignal = Drift::Advise(InpDriftBreakoutRatio, InpDriftMeanRevRatio);
        PrintFormat("DEBUG: AUTO MODE - Drift signal is: %d (1=Breakout, -1=MeanRevert)", driftSignal);
        if(driftSignal == 1) mode_to_run = MODE_BREAKOUT;
        else if(driftSignal == -1) mode_to_run = MODE_MEANREVERT;
        else mode_to_run = (StrategyMode)-1; // No strategy
    } else {
        PrintFormat("DEBUG: MANUAL MODE - Strategy forced to: %s", EnumToString(mode_to_run));
    }
    
    bool trade_executed = false;
    
    if(mode_to_run == MODE_BREAKOUT)
    {
        Print("DEBUG: Executing BREAKOUT strategy...");
        // --- FIX #3: Add all 13 required parameters to the function call ---
        trade_executed = StrategyBreakout::Run(_Symbol, 
                                                (StrategyBreakout::BoxMode)InpBoxMode, 
                                                InpBreakoutLookback,
                                                InpBreakoutTimeFrom,
                                                InpBreakoutTimeTo,
                                                InpBreakoutBufferPts,
                                                InpBreakoutRequiresClose, // Missing parameter added
                                                atr,
                                                InpAtrMultSL,
                                                InpAtrMultTP,
                                                InpRiskPercentPerTrade,
                                                InpBreakoutUsePending,
                                                InpMinAtrFilterPts * _Point); // Missing parameter added
        if (trade_executed) Print("DEBUG: BREAKOUT - ATTEMPTING TRADE."); else Print("DEBUG: BREAKOUT - Conditions not met, no trade.");
    }
    else if(mode_to_run == MODE_MEANREVERT)
    {
        Print("DEBUG: Executing MEAN REVERT strategy...");
        trade_executed = StrategyMeanRevert::Run(_Symbol, 
                                                  InpMR_EMAPeriod,
                                                  InpMR_ZScoreThresh,
                                                  atr,
                                                  InpAtrMultSL,
                                                  InpAtrMultTP,
                                                  InpRiskPercentPerTrade);
        if (trade_executed) Print("DEBUG: MEAN REVERT - ATTEMPTING TRADE."); else Print("DEBUG: MEAN REVERT - Conditions not met, no trade.");
    }
    else
    {
        Print("DEBUG: No strategy executed (Drift signal is neutral or manual mode is off).");
    }

    if (trade_executed)
    {
        Utils::StampTradeTime();
        Print("DEBUG: Trade attempt recorded. Stamping cooldown time.");
    }
}

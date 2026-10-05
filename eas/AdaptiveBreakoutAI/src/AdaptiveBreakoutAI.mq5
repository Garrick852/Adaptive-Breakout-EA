#property copyright "Garrick852"
#property link      "https://github.com/Garrick852/Adaptive-Breakout-EA"
#property version   "1.04"
#property strict

// --- Includes ---
#include "utils.mqh"
#include "volatility.mqh"
#include "risk.mqh"
#include "trade_exec.mqh"
#include "prop_rules.mqh"
#include "portfolio.mqh"
#include "strategy_breakout.mqh"
#include "strategy_meanrevert.mqh"
#include "drift_detection.mqh"
#include "SBridgePacket.mqh"      // MI-001: 104-byte AOS<->EA wire contract
#include "observation_tap.mqh"    // MI-002: gating-safe observation tap
#include "aos_command.mqh"        // MI-003: AOS command channel + telemetry routing
#include "escalation.mqh"         // MI-004: 4.5% HWM drawdown escalation rail

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

// Portfolio Risk Guard
input double InpMaxGlobalRiskPct    = 10.0; // Max equity drawdown % before blocking new trades
input double InpGlobalStopOutPct    = 15.0; // Drawdown % to emit a critical portfolio alert

// MI-002: observation tap (gating-safe observability; Phase-1 HOLD posture)
input bool   InpTapEnabled      = true;    // write the 6-feature observation tap (FILE_COMMON)
input int    InpTapIntervalMs   = 1000;    // min ms between atomic rewrites (>= 100)
input int    InpTapStaleMs      = 2500;    // observation older than this => HOLD (>= 250)
input bool   InpEnableTrading   = false;   // Phase-1 HOLD posture; true resumes local trading

// MI-003: AOS command channel (SBridgePacket via FILE_COMMON)
input bool   InpAosCmdEnabled   = true;    // true = AOS-controlled; false = native local strategies
input int    InpAosCmdStaleSec  = 2;       // AOS command older than this => HOLD (plan: >2s disconnect)
input AosSimCmd InpAosSimCmd    = AOS_SIM_OFF; // simulation override for acceptance testing

// --- OnInit ---
int OnInit()
{
    Print("AdaptiveBreakoutAI EA Initializing...");

    // --- MI-001: 104-byte SBridgePacket wire-contract self-check (HOLD-safe) ---
    if(!SBPacketValidateLayout())
    {
        Print("SBridgePacket layout validation FAILED - staying HOLD (EA will not trade).");
        return(INIT_FAILED);
    }
    PrintFormat("Packet Size: %d (contract %d bytes)", (int)sizeof(SBridgePacket), SB_PACKET_SIZE);

    // --- MI-002: observation tap init (HOLD-safe) ---
    ObservationTap::Configure(InpTapEnabled, InpTapIntervalMs, InpTapStaleMs,
                              InpDriftBreakoutRatio, InpDriftMeanRevRatio);
    if(!ObservationTap::Init())
    {
        Print("ObservationTap init FAILED - staying HOLD (EA will not trade).");
        return(INIT_FAILED);
    }

    // --- MI-003: AOS command channel init ---
    AosCommand::Configure(InpAosCmdEnabled, InpAosCmdStaleSec, (int)InpAosSimCmd);
    PrintFormat("EXECUTION: mode=%s, armed=%s",
                InpAosCmdEnabled ? "AOS-controlled" : "native",
                InpEnableTrading ? "true" : "false (HOLD)");

    // --- MI-004: escalation controller init (governance-locked 4.5% cap) ---
    Escalation::Init();

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
    ObservationTap::Deinit();
    Print("AdaptiveBreakoutAI EA Deinitializing. Reason: ", reason);
}

// --- OnTick ---
void OnTick()
{
    // --- MI-004: escalation rail FIRST (highest priority; safety over everything) ---
    if(Escalation::OnTick(_Symbol))
    {
        AosCommand::WriteStatus(_Symbol, AOS_STATE_BLOCK, SB_STATUS_LOCKED, SB_FLAG_RISK_VETO);
        return;   // locked: no trades, no AOS command processing (any BUY ignored)
    }

    // --- MI-002/003: observation tap + AOS command gating (runs EVERY tick) ---
    static datetime last_hold_print = 0;
    bool obsOk = ObservationTap::OnTick(_Symbol);
    int aosCmd = InpAosCmdEnabled ? AosCommand::ReadCommand(_Symbol) : AOS_STATE_UNKNOWN;
    bool aosOk = (!InpAosCmdEnabled) || AosCommand::PriorityGate(aosCmd);
    if(!obsOk || !aosOk || !InpEnableTrading)
    {
        int st = SB_STATUS_OK;
        int fl = 0;
        if(!obsOk)      { st = SB_STATUS_STALE; }
        else if(!aosOk) { st = SB_STATUS_ERROR; }
        else            { fl = SB_FLAG_RISK_VETO; }   // operator HOLD (Phase 1)
        AosCommand::WriteStatus(_Symbol, AOS_STATE_HOLD, st, fl);
        if(TimeCurrent() - last_hold_print >= 5)
        {
            if(!obsOk)
                Print("OBS-TAP: observation invalid/stale -> HOLD (no trade evaluation)");
            else if(!aosOk)
                PrintFormat("AOS-CMD: command %d not tradeable (BLOCK/UNKNOWN/stale) -> HOLD", aosCmd);
            else
                Print("HOLD mode (MI-002/003 Phase 1): InpEnableTrading=false");
            last_hold_print = TimeCurrent();
        }
        return;
    }
    // Native strategies choose either direction; controlled mode has already passed PriorityGate.
    TradeExec::Direction allowedDir = !InpAosCmdEnabled ? TradeExec::DIR_ANY :
                                     (aosCmd == AOS_STATE_BUY ? TradeExec::DIR_BUY : TradeExec::DIR_SELL);

    static datetime last_print_time = 0;
    if (TimeCurrent() - last_print_time < 5) return;
    last_print_time = TimeCurrent();
    PrintFormat("--------------------------------------------------");
    PrintFormat("Tick received for %s at %s", _Symbol, TimeToString(TimeCurrent()));

    if (InpUseSessionFilter) {
        if (!Utils::IsWithinSession(InpSessionStartHour, InpSessionEndHour)) {
            AosCommand::WriteStatus(_Symbol, AOS_STATE_HOLD, SB_STATUS_OK, SB_FLAG_RISK_VETO); // local veto
            PrintFormat("DEBUG: FAIL - Trading session is not active.");
            return;
        }
    }
    Print("DEBUG: PASS - Session check passed.");

    if (!PropRules::AllowTrading(InpOperMode, InpDailyLossStopPct, InpMaxTotalDDPct)) {
        AosCommand::WriteStatus(_Symbol, AOS_STATE_HOLD, SB_STATUS_OK, SB_FLAG_RISK_VETO); // local veto
        Print("DEBUG: FAIL - Prop rules prevent trading.");
        return;
    }
    Print("DEBUG: PASS - Prop rules check passed.");

    PortfolioAgent::GlobalMonitor(InpGlobalStopOutPct);
    if (!PortfolioAgent::AllowNewTrade(InpMaxGlobalRiskPct)) {
        AosCommand::WriteStatus(_Symbol, AOS_STATE_HOLD, SB_STATUS_OK, SB_FLAG_RISK_VETO); // local veto
        Print("DEBUG: FAIL - Portfolio equity drawdown limit reached.");
        return;
    }
    Print("DEBUG: PASS - Portfolio risk check passed.");

    if (!Utils::PassedCooldownMinutes(InpMinMinutesBetweenTrades)) {
        AosCommand::WriteStatus(_Symbol, AOS_STATE_HOLD, SB_STATUS_OK, SB_FLAG_RISK_VETO); // local veto
        PrintFormat("DEBUG: FAIL - In cooldown period.");
        return;
    }
    Print("DEBUG: PASS - Cooldown check passed.");

    if (Risk::HasOpenPosition(_Symbol)) {
        AosCommand::WriteStatus(_Symbol, AOS_STATE_HOLD, SB_STATUS_OK, SB_FLAG_RISK_VETO); // local veto
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
                                                InpMinAtrFilterPts * _Point, // Missing parameter added
                                                allowedDir);
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
                                                  InpRiskPercentPerTrade,
                                                  allowedDir);
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
        PrintFormat("EXECUTION: mode=%s, local strategy order attempt recorded",
                    InpAosCmdEnabled ? "AOS-controlled" : "native");
    }

    // The wire has no native-action code; never invent a publisher BUY/SELL.
    AosCommand::WriteStatus(_Symbol,
                            (InpAosCmdEnabled && trade_executed) ? aosCmd : AOS_STATE_HOLD,
                            SB_STATUS_OK,
                            0);
}

//+------------------------------------------------------------------+
//| MI-005: headless WFO evaluator (OnTester).                        |
//|                                                                    |
//| Fitness: (ProfitFactor * RecoveryFactor) / max(MaxDD, EPSILON_DD)  |
//|   - MaxDD = peak DAY-RESET HWM drawdown from Escalation (the SAME |
//|     metric/reset policy as the live MI-004 rail - no drift).      |
//|   - Reject (-1.0) when: trades < gate, PF/RF invalid, MaxDD >=    |
//|     the governance cap, or any stat is invalid (fail-closed).     |
//|   - No UI, no popups; pure genetic-optimizer score.               |
//| Constants are GOVERNED (not inputs): the optimizer must not be    |
//| able to tune them away.                                           |
//+------------------------------------------------------------------+
double OnTester()
{
    const double EPSILON_DD = 0.001;   // denominator floor (0.1%) - prevents explosion at low DD
    const int    MIN_TRADES  = 20;     // overfit gate: reject too-few-trade runs

    double trades = TesterStatistics(STAT_TRADES);
    if(!MathIsValidNumber(trades) || trades < (double)MIN_TRADES)
        return(-1.0);                  // fail-closed: not enough evidence

    double pf = TesterStatistics(STAT_PROFIT_FACTOR);
    double rf = TesterStatistics(STAT_RECOVERY_FACTOR);
    if(!MathIsValidNumber(pf) || !MathIsValidNumber(rf) || pf <= 0.0 || rf <= 0.0)
        return(-1.0);                  // fail-closed: invalid stats

    double maxDd = Escalation::PeakDayDdFraction();
    if(!MathIsValidNumber(maxDd) || maxDd < 0.0)
        return(-1.0);                  // fail-closed: invalid drawdown
    if(maxDd >= ESCALATION_MAX_DD_FRACTION)
        return(-1.0);                  // reject runs over the 4.5% cap (same boundary as live)

    double denom = MathMax(maxDd, EPSILON_DD);
    return((pf * rf) / denom);
}

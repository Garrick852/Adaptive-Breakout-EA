//+------------------------------------------------------------------+
//| AdaptiveBreakoutAI.mq5 - Adaptive breakout / mean-revert EA      |
//+------------------------------------------------------------------+
#property strict

//--- Includes
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
// Inputs
//-------------------------------------------------------------------
// Session filter
input bool   InpUseSessionFilter    = false; // Use session filter
input int    InpSessionStartHour    = 0;     // Session start hour (server time)
input int    InpSessionEndHour      = 23;    // Session end hour (server time)

// Prop rules / daily loss / total DD / cooldown
input int    InpOperMode            = PropRules::MODE_NORMAL; // Operation mode
input double InpDailyLossStopPct    = 5.0;   // Max daily loss (%) of balance
input double InpMaxTotalDDPct       = 10.0;  // Max total drawdown (%) of balance
input int    InpMinMinutesBetweenTrades = 5; // Cooldown between trades (minutes)

// Hedging / concurrency
input bool   InpHedgingDisabled     = true;  // Block trades if opposite position exists
input int    InpMaxConcurrentTrades = 1;     // Max open trades per symbol

// Volatility / ATR
input int    InpATRPeriod           = 14;    // ATR period
input double InpMinATRFilter        = 0.0;   // Min ATR filter (0 = disabled)

// Box settings
input BoxModeInput InpBoxMode       = BOXMODE_DONCHIAN; // Box mode
input int    InpBoxLookbackBars     = 50;    // Donchian bars lookback
input int    InpTimeFromHour        = 8;     // Time-range box start hour
input int    InpTimeToHour          = 17;    // Time-range box end hour

// Breakout behaviour
input double InpBreakoutBufferPts   = 20;    // Breakout buffer (points beyond box)
input bool   InpRequireCloseBeyond  = true;  // Require candle close beyond box

// SL/TP and risk
input double InpATRMultSL           = 2.0;   // SL in ATR multiples
input double InpATRMultTP           = 4.0;   // TP in ATR multiples
input double InpRiskPercentPerTrade = 1.0;   // Risk per trade (% of balance)
input bool   InpUsePendingOrders    = false; // Use pending stop orders instead of market

// Strategy mode / AI router
input StrategyMode InpStrategyMode  = MODE_AUTO; // Strategy mode
input bool         InpAIEnabled     = true;      // Enable external AI + drift router
input string       InpAISignalFile  = "ai_signal.txt"; // File with -1,0,1 AI signal

// ATR trailing stop (optional)
input bool   InpUseATRTrail         = false; // Use ATR-based trailing stop
input double InpATRTrailMult        = 1.5;   // ATR trailing multiplier

//-------------------------------------------------------------------
// Expert initialization
//-------------------------------------------------------------------
int OnInit()
  {
   Drift::Init();
   return(INIT_SUCCEEDED);
  }

//-------------------------------------------------------------------
// Expert deinitialization
//-------------------------------------------------------------------
void OnDeinit(const int reason)
  {
   Print("AdaptiveBreakoutAI: deinit, reason=", reason);
  }

//-------------------------------------------------------------------
// Expert tick
//-------------------------------------------------------------------
void OnTick()
  {
   string symbol = _Symbol;

   // Session filter
   if(InpUseSessionFilter && !Utils::IsWithinSession(InpSessionStartHour, InpSessionEndHour))
      return;

   // Prop rules & cooldown
   if(!PropRules::AllowTrading((int)InpOperMode, InpDailyLossStopPct, InpMaxTotalDDPct))
      return;
   if(!Utils::PassedCooldownMinutes(InpMinMinutesBetweenTrades))
      return;

   // Hedging disabled & max concurrency
   if(InpHedgingDisabled && Risk::HasOpenPosition(symbol))
      return;
   if(Risk::CountSymbolPositions(symbol) >= InpMaxConcurrentTrades)
      return;

   // Volatility
   double atr = Volatility::ATR(symbol, PERIOD_CURRENT, InpATRPeriod);
   if(InpMinATRFilter > 0 && atr < InpMinATRFilter)
      return;

   // Build box (for drift & breakout), then update drift detector
   double boxHigh, boxLow;
   bool hasBox = (InpBoxMode == BOXMODE_DONCHIAN)
      ? Box::Donchian(symbol, InpBoxLookbackBars, boxHigh, boxLow)
      : Box::TimeRange(symbol, InpTimeFromHour, InpTimeToHour, boxHigh, boxLow);

   if(hasBox)
      Drift::Update(atr, boxHigh, boxLow);

   // AI / router selection
   StrategyMode mode = InpStrategyMode;
   if(mode == MODE_AUTO && InpAIEnabled)
     {
      int aiSig = Utils::ReadAISignal(InpAISignalFile);   // -1,0,1 from file
      int drift = Drift::Advise();                        // -1,0,1 regime advice
      int fused = (aiSig != 0 ? aiSig : drift);
      mode = (fused > 0 ? MODE_BREAKOUT : (fused < 0 ? MODE_MEANREVERT : MODE_BREAKOUT));
     }

   bool traded = false;
   if(mode == MODE_BREAKOUT)
     {
      traded = StrategyBreakout::Run(
                  symbol,
                  (StrategyBreakout::BoxMode)InpBoxMode,
                  InpBoxLookbackBars,
                  InpTimeFromHour,
                  InpTimeToHour,
                  InpBreakoutBufferPts,
                  InpRequireCloseBeyond,
                  atr,
                  InpATRMultSL,
                  InpATRMultTP,
                  InpRiskPercentPerTrade,
                  InpUsePendingOrders,
                  InpMinATRFilter);
     }
   else // MODE_MEANREVERT
     {
      traded = StrategyMeanRevert::Run(
                  symbol,
                  50,    // EMA period
                  1.5,   // z-score threshold
                  atr,
                  InpATRMultSL,
                  InpATRMultTP,
                  InpRiskPercentPerTrade);
     }

   if(traded)
      Utils::StampTradeTime();

   // Trailing – comment out if you don't implement Strategy::ATRTrail
   // if(InpUseATRTrail)
   //    Strategy::ATRTrail(symbol, atr, InpATRTrailMult);
  }

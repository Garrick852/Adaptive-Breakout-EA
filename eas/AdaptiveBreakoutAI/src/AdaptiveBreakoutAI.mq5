//+------------------------------------------------------------------+
//| AdaptiveBreakoutAI.mq5                                           |
//| Demo-ready scaffold with regime gating, sensitivity scoring,     |
//| drift detection, risk caps, and glyph diagnostics.               |
//+------------------------------------------------------------------+
#property copyright "fh"
#property version   "0.3.0"
#property strict
#include <Trade\Trade.mqh>
#include "drift_detection.mqh"

// -------------------- Inputs (demo defaults) -----------------------
input double   BreakoutBufferBase      = 10.0;    // base points beyond high/low
input int      BreakoutWindow          = 50;      // lookback window for breakout
input int      VolatilityWindow        = 20;      // lookback window for volatility
input double   SensitivityThreshold    = 0.60;    // gate for entries
input ENUM_TIMEFRAMES RegimeTF         = PERIOD_H1;

input double   LotSize                 = 0.10;    // demo fixed lot
input double   MaxDailyLossPct         = 1.50;    // demo cap (percent of balance)
input double   MaxDrawdownPct          = 5.00;    // demo cap (percent of balance)
input int      MinSecondsBetweenTrades = 60;      // rate limit

// -------------------- State ----------------------------------------
CTrade trade;
double sensitivityScore = 0.0;
string currentRegime    = "Unknown";
datetime lastTradeTime  = 0;
double startBalance     = 0.0;

// -------------------- Helpers --------------------------------------
void EmitGlyph(const string type, const double value) { PrintFormat("Glyph: %s = %.5f", type, value); }
void EmitGlyph(const string type, const string note)  { PrintFormat("Glyph: %s - %s", type, note); }

bool ValidateInputs()
{
   bool ok = true;
   if(BreakoutWindow < 1) { Print("Invalid BreakoutWindow < 1"); ok = false; }
   if(VolatilityWindow < 1){ Print("Invalid VolatilityWindow < 1"); ok = false; }
   if(SensitivityThreshold < 0.0 || SensitivityThreshold > 1.0) { Print("SensitivityThreshold out of [0,1]"); ok = false; }
   if(LotSize <= 0.0) { Print("LotSize must be > 0"); ok = false; }
   if(MaxDailyLossPct < 0.0 || MaxDrawdownPct < 0.0) { Print("Risk caps must be >= 0"); ok = false; }
   return(ok);
}

// Demo regime detection: reads basic slope on RegimeTF
string DetectRegime()
{
   int bars = iBars(_Symbol, RegimeTF);
   if(bars < 3) return("Unknown");
   double p0 = iClose(_Symbol, RegimeTF, 0);
   double p1 = iClose(_Symbol, RegimeTF, 1);
   double p2 = iClose(_Symbol, RegimeTF, 2);
   double slope = (p0 - p2) / MathMax(1e-6, 2.0);
   // Simple gating
   if(slope > 0) return("Trend");
   if(slope < 0) return("DownTrend");
   return("Sideways");
}

// Demo sensitivity scoring: normalized ATR vs buffer
double CalculateSensitivityScore()
{
   double atr = iATR(_Symbol, PERIOD_CURRENT, VolatilityWindow, 0);
   double score = atr / MathMax(1e-6, BreakoutBufferBase * _Point);
   // Bound to [0,1] for gating
   score = MathMin(1.0, MathMax(0.0, score));
   return(score);
}



// Basic rate limiting
bool CanTradeNow()
{
   if(TimeCurrent() - lastTradeTime < MinSecondsBetweenTrades) return(false);
   return(true);
}

// Risk caps (demo): check unrealized+realized change vs caps
bool RiskCapsBreached()
{
   double bal    = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyCap = MaxDailyLossPct / 100.0 * startBalance;
   double ddCap    = MaxDrawdownPct  / 100.0 * startBalance;

   double dailyLossApprox = startBalance - equity; // simplification for demo
   double drawdownApprox  = startBalance - equity;

   if(dailyLossApprox > dailyCap) { Print("Daily loss cap breached"); EmitGlyph("DailyLossCapBreached", 1.0); return(true); }
   if(drawdownApprox  > ddCap)    { Print("Drawdown cap breached");   EmitGlyph("DrawdownCapBreached", 1.0);  return(true); }
   return(false);
}

// Simple breakout condition: price exceeds recent high by buffer in points
bool CheckBreakoutEntry()
{
   int bars = Bars(_Symbol, PERIOD_CURRENT);
   if(bars <= BreakoutWindow + 2) return(false);

   currentRegime    = DetectRegime();
sensitivityScore = CalculateSensitivityScore();

   EmitGlyph("Regime", currentRegime);
   EmitGlyph("SensitivityScore", sensitivityScore);

   double highest = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, BreakoutWindow, 1));
   double buffer  = BreakoutBufferBase * _Point;
   double price   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   bool breakoutUp = (price > highest + buffer);
   EmitGlyph("BreakoutUp", breakoutUp ? 1.0 : 0.0);

   if(sensitivityScore >= SensitivityThreshold && currentRegime == "Trend" && breakoutUp)
      return(true);
   return(false);
}

// -------------------- Lifecycle ------------------------------------
int OnInit()
{
   if(!ValidateInputs()) return(INIT_PARAMETERS_INCORRECT);
   trade.SetExpertMagicNumber(123456); // demo magic
   startBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   Print("AdaptiveBreakoutAI initialized (demo). Symbol=", _Symbol);
   EmitGlyph("EAInit", 1.0);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EmitGlyph("EADeinitReason", (double)reason);
   Print("AdaptiveBreakoutAI deinitialized.");
}

void OnTick()
{
   // Monitor drift detection module
   MonitorDrift();

   // Basic pre-trade checks
   if(!CanTradeNow()) return;
   if(RiskCapsBreached()) return;
   if(IsModelDrifting()) { EmitGlyph("TradingHalted", "Model drift detected"); return; }

   // Demo entry: buy when breakout condition passes
   if(CheckBreakoutEntry())
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double vol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double lot  = MathMax(vol, MathFloor(LotSize / step) * step);

      bool ok = trade.Buy(lot, _Symbol, ask, 0, 0, "AdaptiveBreakoutAI demo");
      if(ok)
      {
         lastTradeTime = TimeCurrent();
         EmitGlyph("TradePlaced", 1.0);
         PrintFormat("Buy placed: lot=%.2f price=%.5f", lot, ask);
      }
      else
      {
         EmitGlyph("TradeError", 1.0);
         Print("Trade failed: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| strategy_meanrevert.mqh - Mean‑reversion strategy                |
//| For AdaptiveBreakoutAI                                           |
//+------------------------------------------------------------------+
#ifndef __STRATEGY_MEANREVERT_MQH__
#define __STRATEGY_MEANREVERT_MQH__

#include "trade_exec.mqh"
#include "volatility.mqh"

namespace StrategyMeanRevert
  {
   using TradeExec::Direction;
   using namespace TradeExec;

   // Simple z‑score mean reversion:
   //  - emaPeriod: EMA period for "fair value"
   //  - zATR:     threshold in ATR multiples (e.g. 1.5)
   //  - atrMultSL/TP: SL/TP based on ATR multiples
   //  - riskPercentPerTrade: risk% of balance
   bool Run(string symbol,
            int emaPeriod,
            double zATR,
            double atr,
            double atrMultSL,
            double atrMultTP,
            double riskPercentPerTrade)
     {
      if(atr <= 0.0)
        {
         Print("StrategyMeanRevert::Run -> ATR <= 0, abort");
         return(false);
        }

      ENUM_TIMEFRAMES tf = PERIOD_CURRENT;
      int bars = iBars(symbol, tf);
      if(bars < emaPeriod + 2)
        {
         Print("StrategyMeanRevert::Run -> not enough bars");
         return(false);
        }

      int emaHandle = iMA(symbol, tf, emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(emaHandle == INVALID_HANDLE)
        {
         Print("StrategyMeanRevert::Run -> iMA invalid handle");
         return(false);
        }

      double emaArr[];
      if(CopyBuffer(emaHandle, 0, 0, 2, emaArr) != 2)
        {
         Print("StrategyMeanRevert::Run -> CopyBuffer failed");
         return(false);
        }

      double ema = emaArr[0];
      double price = SymbolInfoDouble(symbol, SYMBOL_BID); // reference price
      double deviation = price - ema;

      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double devPoints = deviation / point;
      double atrPoints = atr / point;

      if(atrPoints <= 0.0)
        {
         Print("StrategyMeanRevert::Run -> atrPoints <= 0");
         return(false);
        }

      double z = devPoints / atrPoints;
      // mean‑revert: if price >> ema, SELL; if price << ema, BUY
      bool buySignal  = (z <= -zATR);
      bool sellSignal = (z >=  zATR);

      if(!buySignal && !sellSignal)
        return(false);

      // SL/TP
      double slPoints = atrMultSL * atrPoints;
      double tpPoints = atrMultTP * atrPoints;
      if(slPoints <= 0.0)
        {
         Print("StrategyMeanRevert::Run -> slPoints <= 0");
         return(false);
        }

      double lots = TradeExec::CalcLotsByRisk(symbol, riskPercentPerTrade, slPoints);
      if(lots <= 0.0)
        {
         Print("StrategyMeanRevert::Run -> lots <= 0");
         return(false);
        }

      Direction dir;
      double entryPrice, slPrice, tpPrice;

      if(buySignal)
        {
         dir        = DIR_BUY;
         entryPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
         slPrice    = entryPrice - slPoints * point;
         tpPrice    = entryPrice + tpPoints * point;
        }
      else // sellSignal
        {
         dir        = DIR_SELL;
         entryPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
         slPrice    = entryPrice + slPoints * point;
         tpPrice    = entryPrice - tpPoints * point;
        }

      bool result = TradeExec::MarketOrder(symbol, dir, slPrice, tpPrice, lots);
      if(result)
        {
         Print("StrategyMeanRevert::Run -> trade opened, symbol=", symbol,
               " dir=", (buySignal ? "LONG" : "SHORT"),
               " z=", DoubleToString(z, 2),
               " lots=", DoubleToString(lots, 2));
         return(true);
        }

      return(false);
     }
  }

#endif // __STRATEGY_MEANREVERT_MQH__

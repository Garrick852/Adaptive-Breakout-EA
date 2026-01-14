//+------------------------------------------------------------------+
//| strategy_breakout.mqh - Breakout logic & box construction        |
//| For AdaptiveBreakoutAI                                           |
//+------------------------------------------------------------------+
#ifndef __STRATEGY_BREAKOUT_MQH__
#define __STRATEGY_BREAKOUT_MQH__

#include "trade_exec.mqh"
#include "utils.mqh"
#include "risk.mqh"
#include "volatility.mqh"

namespace Box
  {
   enum BoxMode
     {
      BOX_DONCHIAN = 0,
      BOX_TIMERANGE = 1
     };

   // Donchian channel over N bars on current timeframe.
   bool Donchian(string symbol, int lookbackBars, double &boxHigh, double &boxLow)
     {
      if(lookbackBars <= 0)
        {
         Print("Box::Donchian -> invalid lookbackBars: ", lookbackBars);
         return(false);
        }

      int tf = PERIOD_CURRENT;
      int counted = iBars(symbol, tf);
      if(counted < lookbackBars + 1)
        {
         Print("Box::Donchian -> not enough bars: ", counted);
         return(false);
        }

      double highArr[], lowArr[];
      if(CopyHigh(symbol, tf, 1, lookbackBars, highArr) != lookbackBars ||
         CopyLow(symbol,  tf, 1, lookbackBars, lowArr)  != lookbackBars)
        {
         Print("Box::Donchian -> CopyHigh/CopyLow failed");
         return(false);
        }

      boxHigh = highArr[0];
      boxLow  = lowArr[0];
      for(int i=1; i<lookbackBars; i++)
        {
         if(highArr[i] > boxHigh) boxHigh = highArr[i];
         if(lowArr[i]  < boxLow)  boxLow  = lowArr[i];
        }

      // Debug
      // Print("Box::Donchian -> high=", boxHigh, " low=", boxLow);
      return(true);
     }

   // Time‑range box for a given [fromHour,toHour) on current day, server time.
   bool TimeRange(string symbol, int fromHour, int toHour, double &boxHigh, double &boxLow)
     {
      if(fromHour == toHour)
        {
         Print("Box::TimeRange -> fromHour == toHour, invalid");
         return(false);
        }

      ENUM_TIMEFRAMES tf = PERIOD_M5; // default small TF for box scan
      datetime now       = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(now, dt);

      datetime dayStart = StructToTime(dt) - (dt.hour*3600 + dt.min*60 + dt.sec);
      datetime fromTime = dayStart + fromHour * 3600;
      datetime toTime   = dayStart + toHour   * 3600;

      if(toTime < fromTime)
        {
         // wrap across midnight: handle [from, 24) U [0,to)
         toTime += 24*3600;
        }

      int bars = iBars(symbol, tf);
      if(bars < 10)
        {
         Print("Box::TimeRange -> not enough bars");
         return(false);
        }

      boxHigh = -DBL_MAX;
      boxLow  =  DBL_MAX;

      datetime times[];
      double highs[], lows[];
      if(CopyTime(symbol, tf, 0, bars, times) < 1 ||
         CopyHigh(symbol, tf, 0, bars, highs) < 1 ||
         CopyLow(symbol,  tf, 0, bars, lows)  < 1)
        {
         Print("Box::TimeRange -> Copy* failed");
         return(false);
        }

      bool found = false;
      for(int i=0; i<bars; i++)
        {
         datetime t = times[i];
         datetime shifted = t;
         if(shifted < fromTime) shifted += 24*3600;  // simple wrap handling

         if(shifted >= fromTime && shifted < toTime)
           {
            if(highs[i] > boxHigh) boxHigh = highs[i];
            if(lows[i]  < boxLow)  boxLow  = lows[i];
            found = true;
           }
        }

      if(!found)
        {
         Print("Box::TimeRange -> no bars in range");
         return(false);
        }

      // Print("Box::TimeRange -> high=", boxHigh, " low=", boxLow);
      return(true);
     }
  }

namespace StrategyBreakout
  {
   // Cast alias so OnTick can use (StrategyBreakout::BoxMode)InpBoxMode
   using Box::BoxMode;
   using TradeExec::Direction;
   using namespace TradeExec;

   // Core breakout runner:
   //  - boxMode, lookback/time-window build the box
   //  - breakoutBufferPts = distance beyond box high/low to trigger
   //  - requireCloseBeyond: if true, use Close[1] beyond; else use Bid/Ask
   //  - atrMultSL/TP: SL/TP in ATR multiples
   //  - riskPercentPerTrade: risk% of balance
   //  - usePendingOrders: if true, place stop orders, else market
   //  - minATR: for internal extra check if needed
   bool Run(string symbol,
            BoxMode boxMode,
            int boxLookbackBars,
            int timeFromHour,
            int timeToHour,
            double breakoutBufferPts,
            bool requireCloseBeyond,
            double atr,
            double atrMultSL,
            double atrMultTP,
            double riskPercentPerTrade,
            bool usePendingOrders,
            double minATR)
     {
      if(atr <= 0.0)
        {
         Print("StrategyBreakout::Run -> ATR <= 0, abort");
         return(false);
        }

      // Build box
      double boxHigh, boxLow;
      bool hasBox = (boxMode == Box::BOX_DONCHIAN)
        ? Box::Donchian(symbol, boxLookbackBars, boxHigh, boxLow)
        : Box::TimeRange(symbol, timeFromHour, timeToHour, boxHigh, boxLow);

      if(!hasBox)
        {
         // Print("StrategyBreakout::Run -> no valid box");
         return(false);
        }

      double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double bid       = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask       = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double closePrev = iClose(symbol, PERIOD_CURRENT, 1);

      double triggerUp   = boxHigh + breakoutBufferPts * point;
      double triggerDown = boxLow  - breakoutBufferPts * point;

      bool longSignal  = false;
      bool shortSignal = false;

      if(requireCloseBeyond)
        {
         longSignal  = (closePrev > triggerUp);
         shortSignal = (closePrev < triggerDown);
        }
      else
        {
         longSignal  = (ask > triggerUp);
         shortSignal = (bid < triggerDown);
        }

      if(!longSignal && !shortSignal)
        return(false); // no breakout

      // SL/TP distances in points from ATR multiples
      double slPoints = atrMultSL * (atr / point);
      double tpPoints = atrMultTP * (atr / point);

      if(slPoints <= 0.0)
        {
         Print("StrategyBreakout::Run -> slPoints <= 0, abort");
         return(false);
        }

      double lots = TradeExec::CalcLotsByRisk(symbol, riskPercentPerTrade, slPoints);
      if(lots <= 0.0)
        {
         Print("StrategyBreakout::Run -> calculated lots <= 0");
         return(false);
        }

      // Determine direction and prices
      Direction dir;
      double entryPrice, slPrice, tpPrice;

      if(longSignal)
        {
         dir        = DIR_BUY;
         entryPrice = usePendingOrders ? triggerUp : ask;
         slPrice    = entryPrice - slPoints * point;
         tpPrice    = entryPrice + tpPoints * point;
        }
      else // shortSignal
        {
         dir        = DIR_SELL;
         entryPrice = usePendingOrders ? triggerDown : bid;
         slPrice    = entryPrice + slPoints * point;
         tpPrice    = entryPrice - tpPoints * point;
        }

      bool result = false;
      if(usePendingOrders)
        {
         result = TradeExec::PendingStopOrder(symbol, dir, entryPrice, slPrice, tpPrice, lots);
        }
      else
        {
         result = TradeExec::MarketOrder(symbol, dir, slPrice, tpPrice, lots);
        }

      if(result)
        {
         Print("StrategyBreakout::Run -> trade opened, symbol=", symbol,
               " dir=", (longSignal ? "LONG" : "SHORT"),
               " lots=", DoubleToString(lots, 2));
         return(true);
        }

      return(false);
     }
  }

#endif // __STRATEGY_BREAKOUT_MQH__

//+------------------------------------------------------------------+
//| strategy_breakout.mqh - Breakout box and execution               |
//+------------------------------------------------------------------+
#ifndef __STRATEGY_BREAKOUT_MQH__
#define __STRATEGY_BREAKOUT_MQH__

#include "trade_exec.mqh"
#include "risk.mqh"
#include "volatility.mqh"

namespace Box
  {
   enum BoxMode
     {
      BOX_DONCHIAN = 0,
      BOX_TIMERANGE = 1
     };

   bool Donchian(string symbol, int lookbackBars, double &boxHigh, double &boxLow)
     {
      if(lookbackBars <= 0)
        {
         Print("Box::Donchian -> invalid lookbackBars");
         return(false);
        }

      int tf = PERIOD_CURRENT;
      int bars = iBars(symbol, tf);
      if(bars <= lookbackBars)
        {
         Print("Box::Donchian -> not enough bars");
         return(false);
        }

      double highs[], lows[];
      if(CopyHigh(symbol, tf, 1, lookbackBars, highs) != lookbackBars ||
         CopyLow(symbol,  tf, 1, lookbackBars, lows)  != lookbackBars)
        {
         Print("Box::Donchian -> CopyHigh/CopyLow failed");
         return(false);
        }

      boxHigh = highs[0];
      boxLow  = lows[0];
      for(int i=1; i<lookbackBars; i++)
        {
         if(highs[i] > boxHigh) boxHigh = highs[i];
         if(lows[i]  < boxLow)  boxLow  = lows[i];
        }
      return(true);
     }

   bool TimeRange(string symbol, int fromHour, int toHour, double &boxHigh, double &boxLow)
     {
      ENUM_TIMEFRAMES tf = PERIOD_M5;

      int bars = iBars(symbol, tf);
      if(bars < 10)
        {
         Print("Box::TimeRange -> not enough bars");
         return(false);
        }

      datetime now = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(now, dt);
      datetime dayStart = StructToTime(dt) - (dt.hour*3600 + dt.min*60 + dt.sec);

      datetime tFrom = dayStart + fromHour*3600;
      datetime tTo   = dayStart + toHour*3600;
      if(tFrom == tTo)
         return(false);

      datetime times[];
      double highs[], lows[];
      int copiedT = CopyTime(symbol, tf, 0, bars, times);
      int copiedH = CopyHigh(symbol, tf, 0, bars, highs);
      int copiedL = CopyLow(symbol,  tf, 0, bars, lows);
      if(copiedT <= 0 || copiedH <= 0 || copiedL <= 0)
        {
         Print("Box::TimeRange -> Copy* failed");
         return(false);
        }

      boxHigh = -DBL_MAX;
      boxLow  =  DBL_MAX;
      bool found = false;

      for(int i=0; i<copiedT; i++)
        {
         datetime t = times[i];
         MqlDateTime d2;
         TimeToStruct(t, d2);
         datetime baseDay = StructToTime(d2) - (d2.hour*3600 + d2.min*60 + d2.sec);
         datetime barFrom = baseDay + fromHour*3600;
         datetime barTo   = baseDay + toHour*3600;

         if(barFrom < barTo)
           {
            if(t >= barFrom && t < barTo)
              {
               if(highs[i] > boxHigh) boxHigh = highs[i];
               if(lows[i]  < boxLow)  boxLow  = lows[i];
               found = true;
              }
           }
         else // wrap
           {
            if(t >= barFrom || t < barTo)
              {
               if(highs[i] > boxHigh) boxHigh = highs[i];
               if(lows[i]  < boxLow)  boxLow  = lows[i];
               found = true;
              }
           }
        }

      return(found);
     }
  }

namespace StrategyBreakout
  {
   using TradeExec::Direction;
   using namespace TradeExec;
   using namespace Risk;

   enum BoxMode
     {
      BOX_DONCHIAN = 0,
      BOX_TIMERANGE = 1
     };

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
            double /*minATR*/)
     {
      if(atr <= 0.0)
        {
         Print("StrategyBreakout::Run -> ATR <= 0");
         return(false);
        }

      // Box
      double boxHigh, boxLow;
      bool hasBox = (boxMode == BOX_DONCHIAN)
         ? Box::Donchian(symbol, boxLookbackBars, boxHigh, boxLow)
         : Box::TimeRange(symbol, timeFromHour, timeToHour, boxHigh, boxLow);

      if(!hasBox)
         return(false);

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
         return(false);

      double atrPoints = atr / point;
      double slPoints  = atrMultSL * atrPoints;
      double tpPoints  = atrMultTP * atrPoints;

      if(slPoints <= 0.0)
         return(false);

      double lots = Risk::CalcLotsByRisk(symbol, slPoints, riskPercentPerTrade);
      if(lots <= 0.0)
        {
         Print("StrategyBreakout::Run -> lots <= 0");
         return(false);
        }

      Direction dir;
      double entryPrice, slPrice, tpPrice;

      if(longSignal)
        {
         dir        = DIR_BUY;
         entryPrice = usePendingOrders ? triggerUp : ask;
         slPrice    = entryPrice - slPoints * point;
         tpPrice    = entryPrice + tpPoints * point;
        }
      else
        {
         dir        = DIR_SELL;
         entryPrice = usePendingOrders ? triggerDown : bid;
         slPrice    = entryPrice + slPoints * point;
         tpPrice    = entryPrice - tpPoints * point;
        }

      bool res;
      if(usePendingOrders)
         res = TradeExec::PendingStopOrder(symbol, dir, entryPrice, slPrice, tpPrice, lots);
      else
         res = TradeExec::MarketOrder(symbol, dir, slPrice, tpPrice, lots);

      return(res);
     }
  }

#endif // __STRATEGY_BREAKOUT_MQH__

//+------------------------------------------------------------------+
//| strategy_meanrevert.mqh - Mean-reversion logic                   |
//+------------------------------------------------------------------+
#ifndef __STRATEGY_MEANREVERT_MQH__
#define __STRATEGY_MEANREVERT_MQH__

#include "trade_exec.mqh"
#include "risk.mqh"
#include "volatility.mqh"

namespace StrategyMeanRevert
  {
   using TradeExec::Direction;
   using namespace TradeExec;
   using namespace Risk;

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
         Print("StrategyMeanRevert::Run -> ATR <= 0");
         return(false);
        }

      ENUM_TIMEFRAMES tf = PERIOD_CURRENT;
      if(iBars(symbol, tf) < emaPeriod + 2)
        {
         Print("StrategyMeanRevert::Run -> not enough bars");
         return(false);
        }

      int hMA = iMA(symbol, tf, emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(hMA == INVALID_HANDLE)
        {
         Print("StrategyMeanRevert::Run -> invalid MA handle");
         return(false);
        }

      double buf[];
      if(CopyBuffer(hMA, 0, 0, 1, buf) != 1)
        {
         Print("StrategyMeanRevert::Run -> CopyBuffer failed");
         return(false);
        }

      double ema = buf[0];
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double price = bid;

      double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double devPoints = (price - ema) / point;
      double atrPoints = atr / point;
      if(atrPoints <= 0.0)
         return(false);

      double z = devPoints / atrPoints;

      bool buySignal  = (z <= -zATR);
      bool sellSignal = (z >=  zATR);
      if(!buySignal && !sellSignal)
         return(false);

      double slPoints = atrMultSL * atrPoints;
      double tpPoints = atrMultTP * atrPoints;
      if(slPoints <= 0.0)
         return(false);

      double lots = Risk::CalcLotsByRisk(symbol, slPoints, riskPercentPerTrade);
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
         entryPrice = ask;
         slPrice    = entryPrice - slPoints * point;
         tpPrice    = entryPrice + tpPoints * point;
        }
      else
        {
         dir        = DIR_SELL;
         entryPrice = bid;
         slPrice    = entryPrice + slPoints * point;
         tpPrice    = entryPrice - tpPoints * point;
        }

      bool res = TradeExec::MarketOrder(symbol, dir, slPrice, tpPrice, lots);
      if(res)
         Print("StrategyMeanRevert::Run -> opened ", (buySignal ? "BUY" : "SELL"),
               " lots=", DoubleToString(lots, 2), " z=", DoubleToString(z, 2));

      return(res);
     }
  }

#endif // __STRATEGY_MEANREVERT_MQH__

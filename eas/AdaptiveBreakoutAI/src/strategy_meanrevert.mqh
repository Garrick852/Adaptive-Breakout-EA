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

   // emaPeriod      - EMA period for the mean
   // zATR           - z-score threshold in ATR units (e.g. 1.5)
   // atr            - current ATR (already computed by caller)
   // atrMultSL/TP   - SL/TP in ATR multiples
   // riskPercentPerTrade - % of balance to risk
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

      int shift = 1; // Use previous closed candle
      double priceClose = iClose(symbol, tf, shift);
      double ema        = iMA(symbol, tf, emaPeriod, 0, MODE_EMA, PRICE_CLOSE, shift);

      // Deviation from EMA in ATR units
      double diff    = priceClose - ema;
      double zScore  = diff / (atr == 0.0 ? 1.0 : atr);

      // Mean-reversion logic:
      //  - If price is significantly above EMA (zScore > zATR) -> look for SELL
      //  - If price is significantly below EMA (zScore < -zATR) -> look for BUY
      int dirInt = 0;
      if(zScore > zATR)
         dirInt = TradeExec::DIR_SELL;
      else if(zScore < -zATR)
         dirInt = TradeExec::DIR_BUY;

      if(dirInt == 0)
        {
         // No trade signal
         return(false);
        }

      Direction dir = (Direction)dirInt;

      // Position sizing based on risk percent and ATR-stopped distance
      double slDistanceATR = atrMultSL * atr;
      if(slDistanceATR <= 0.0)
        {
         Print("StrategyMeanRevert::Run -> invalid SL distance");
         return(false);
        }

      double lots = Risk::CalcPositionSize(symbol, riskPercentPerTrade, slDistanceATR);
      if(lots <= 0.0)
        {
         Print("StrategyMeanRevert::Run -> position size <= 0");
         return(false);
        }

      // SL / TP prices
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double slPrice, tpPrice;

      if(dir == DIR_BUY)
        {
         slPrice = priceClose - atrMultSL * atr;
         tpPrice = priceClose + atrMultTP * atr;
        }
      else // DIR_SELL
        {
         slPrice = priceClose + atrMultSL * atr;
         tpPrice = priceClose - atrMultTP * atr;
        }

      bool res = TradeExec::MarketOrder(symbol, dir, slPrice, tpPrice, lots);
      if(!res)
        {
         Print("StrategyMeanRevert::Run -> order failed");
         return(false);
        }

      return(true);
     }
  }

#endif // __STRATEGY_MEANREVERT_MQH__

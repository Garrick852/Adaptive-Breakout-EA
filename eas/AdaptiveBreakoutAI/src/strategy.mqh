//+------------------------------------------------------------------+
//| strategy.mqh - Generic helpers (e.g. trailing) for the EA        |
//+------------------------------------------------------------------+
#ifndef __STRATEGY_MQH__
#define __STRATEGY_MQH__

#include <Trade\Trade.mqh>

namespace Strategy
  {
   CTrade g_trailTrade;

   // Simple ATR-based trailing stop for all positions on a symbol.
   // This is intentionally basic and can be refined later.
   void ATRTrail(string symbol, double atr, double atrMult)
     {
      if(atr <= 0.0 || atrMult <= 0.0)
         return;

      double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double trailPts  = atr * atrMult / point;
      if(trailPts <= 0.0)
         return;

      int total = PositionsTotal();
      for(int i = total - 1; i >= 0; --i)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != symbol)
            continue;

         long   type  = PositionGetInteger(POSITION_TYPE);
         double price = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl    = PositionGetDouble(POSITION_SL);
         double bid   = SymbolInfoDouble(symbol, SYMBOL_BID);
         double ask   = SymbolInfoDouble(symbol, SYMBOL_ASK);

         // BUY position: trail SL up
         if(type == POSITION_TYPE_BUY)
           {
            double newSL = bid - trailPts * point;
            if(newSL > sl && newSL < bid)
              {
               g_trailTrade.SetAsyncMode(false);
               g_trailTrade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
              }
           }
         // SELL position: trail SL down
         else if(type == POSITION_TYPE_SELL)
           {
            double newSL = ask + trailPts * point;
            if((sl == 0.0 || newSL < sl) && newSL > ask)
              {
               g_trailTrade.SetAsyncMode(false);
               g_trailTrade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
              }
           }
        }
     }
  }

#endif // __STRATEGY_MQH__

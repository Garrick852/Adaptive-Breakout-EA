//+------------------------------------------------------------------+
//| strategy.mqh - Generic helpers (e.g. ATR-based trailing)         |
//| For AdaptiveBreakoutAI                                           |
//+------------------------------------------------------------------+
#ifndef __STRATEGY_MQH__
#define __STRATEGY_MQH__

#include <Trade\Trade.mqh>

namespace Strategy
  {
   CTrade g_trailTrade;

   // ATR-based trailing stop for all positions on a symbol.
   //  - atr: current ATR (same as you passed into strategies)
   //  - atrMult: trailing distance in ATR multiples
   //
   // Logic:
   //  - For BUY: SL = max(old SL, Bid - atrMult * ATR), but always below Bid
   //  - For SELL: SL = min(old SL (if set), Ask + atrMult * ATR), but always above Ask
   void ATRTrail(string symbol, double atr, double atrMult)
     {
      if(atr <= 0.0 || atrMult <= 0.0)
         return;

      double point    = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double trailPts = (atr * atrMult) / point;
      if(trailPts <= 0.0)
         return;

      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

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
         double sl    = PositionGetDouble(POSITION_SL);
         double tp    = PositionGetDouble(POSITION_TP);

         // BUY position: trail SL up
         if(type == POSITION_TYPE_BUY)
           {
            double newSL = bid - trailPts * point;

            // Only move SL up (never down), and keep it below current Bid
            if((sl == 0.0 || newSL > sl) && newSL < bid)
              {
               g_trailTrade.SetAsyncMode(false);
               if(!g_trailTrade.PositionModify(ticket, newSL, tp))
                 {
                  Print("Strategy::ATRTrail BUY -> modify failed, ticket=", ticket,
                        " err=", g_trailTrade.ResultRetcode(), " ",
                        g_trailTrade.ResultRetcodeDescription());
                 }
              }
           }
         // SELL position: trail SL down
         else if(type == POSITION_TYPE_SELL)
           {
            double newSL = ask + trailPts * point;

            // Only move SL down (if SL not set or newSL < old SL), and keep it above current Ask
            if((sl == 0.0 || newSL < sl) && newSL > ask)
              {
               g_trailTrade.SetAsyncMode(false);
               if(!g_trailTrade.PositionModify(ticket, newSL, tp))
                 {
                  Print("Strategy::ATRTrail SELL -> modify failed, ticket=", ticket,
                        " err=", g_trailTrade.ResultRetcode(), " ",
                        g_trailTrade.ResultRetcodeDescription());
                 }
              }
           }
        }
     }
  }

#endif // __STRATEGY_MQH__

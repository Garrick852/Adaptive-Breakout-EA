//+------------------------------------------------------------------+
//| trade_exec.mqh - Basic execution helpers                         |
//+------------------------------------------------------------------+
#ifndef __TRADE_EXEC_MQH__
#define __TRADE_EXEC_MQH__

#include <Trade\Trade.mqh>

namespace TradeExec
  {
   CTrade trade;

   enum Direction
     {
      DIR_BUY  =  1,
      DIR_SELL = -1
     };

   double NormalizeLots(string symbol, double lots)
     {
      double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

      if(lots < minLot) lots = minLot;
      if(lots > maxLot) lots = maxLot;

      double steps = MathFloor((lots - minLot) / stepLot + 0.5);
      lots = minLot + steps * stepLot;
      return(lots);
     }

   bool MarketOrder(string symbol,
                    Direction dir,
                    double slPrice,
                    double tpPrice,
                    double lots)
     {
      lots = NormalizeLots(symbol, lots);
      if(lots <= 0.0)
         return(false);

      trade.SetExpertMagicNumber(123456);
      trade.SetAsyncMode(false);

      bool res = false;
      if(dir == DIR_BUY)
         res = trade.Buy(lots, symbol, 0.0, slPrice, tpPrice);
      else
         res = trade.Sell(lots, symbol, 0.0, slPrice, tpPrice);

      if(!res)
         Print("TradeExec::MarketOrder -> failed: ", trade.ResultRetcodeDescription());
      return(res);
     }

   bool PendingStopOrder(string symbol,
                         Direction dir,
                         double price,
                         double slPrice,
                         double tpPrice,
                         double lots,
                         datetime expiration = 0)
     {
      lots = NormalizeLots(symbol, lots);
      if(lots <= 0.0)
         return(false);

      trade.SetExpertMagicNumber(123456);
      trade.SetAsyncMode(false);

      bool res = false;
      if(dir == DIR_BUY)
         res = trade.BuyStop(lots, symbol, price, 0, slPrice, tpPrice, "", expiration);
      else
         res = trade.SellStop(lots, symbol, price, 0, slPrice, tpPrice, "", expiration);

      if(!res)
         Print("TradeExec::PendingStopOrder -> failed: ", trade.ResultRetcodeDescription());
      return(res);
     }
  }

#endif // __TRADE_EXEC_MQH__

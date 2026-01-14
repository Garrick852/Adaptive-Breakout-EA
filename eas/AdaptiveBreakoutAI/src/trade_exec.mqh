//+------------------------------------------------------------------+
//| trade_exec.mqh - Order/position execution helpers                |
//| For AdaptiveBreakoutAI                                           |
//+------------------------------------------------------------------+
#ifndef __TRADE_EXEC_MQH__
#define __TRADE_EXEC_MQH__

#include <Trade\Trade.mqh>

namespace TradeExec
  {
   CTrade trade;  // single shared trader

   // Direction enum: +1 = BUY, -1 = SELL
   enum Direction
     {
      DIR_BUY  =  1,
      DIR_SELL = -1
     };

   // Normalize lots to symbol constraints
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

   // Basic lot sizing from risk% and SL distance in points
   double CalcLotsByRisk(string symbol, double riskPercent, double slPoints)
     {
      if(riskPercent <= 0.0 || slPoints <= 0.0)
        {
         Print("TradeExec::CalcLotsByRisk -> invalid params, risk=", riskPercent,
               " slPoints=", slPoints);
         return(0.0);
        }

      double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskMoney = balance * riskPercent / 100.0;   // risk% of balance
      double tickVal   = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

      if(tickVal <= 0 || tickSize <= 0)
        {
         Print("TradeExec::CalcLotsByRisk -> invalid tick parameters for ", symbol);
         return(0.0);
        }

      // Loss per lot for the SL distance (approx)
      double pricePerPoint = tickVal / tickSize;
      double lossPerLot    = pricePerPoint * slPoints;

      if(lossPerLot <= 0)
        {
         Print("TradeExec::CalcLotsByRisk -> non‑positive lossPerLot for ", symbol);
         return(0.0);
        }

      double lots = riskMoney / lossPerLot;
      lots = NormalizeLots(symbol, lots);
      return(lots);
     }

   // Market order execution
   bool MarketOrder(string symbol,
                    Direction dir,
                    double slPrice,
                    double tpPrice,
                    double lots)
     {
      lots = NormalizeLots(symbol, lots);
      if(lots <= 0.0)
        {
         Print("TradeExec::MarketOrder -> lots <= 0, abort");
         return(false);
        }

      trade.SetExpertMagicNumber(123456); // Adjust if you have a global magic
      trade.SetAsyncMode(false);

      bool result = false;
      if(dir == DIR_BUY)
        {
         result = trade.Buy(lots, symbol, 0.0, slPrice, tpPrice);
        }
      else // DIR_SELL
        {
         result = trade.Sell(lots, symbol, 0.0, slPrice, tpPrice);
        }

      if(!result)
        {
         Print("TradeExec::MarketOrder -> failed, retcode=",
               trade.ResultRetcode(), " desc=", trade.ResultRetcodeDescription());
         return(false);
        }

      Print("TradeExec::MarketOrder -> success: ",
            (dir == DIR_BUY ? "BUY " : "SELL "), lots, " ", symbol,
            " SL=", DoubleToString(slPrice, _Digits),
            " TP=", DoubleToString(tpPrice, _Digits));
      return(true);
     }

   // Pending order: basic stop orders
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
        {
         Print("TradeExec::PendingStopOrder -> lots <= 0, abort");
         return(false);
        }

      trade.SetExpertMagicNumber(123456);
      trade.SetAsyncMode(false);

      bool result = false;
      if(dir == DIR_BUY)
        {
         result = trade.BuyStop(lots, symbol, price, 0, slPrice, tpPrice, "", expiration);
        }
      else // DIR_SELL
        {
         result = trade.SellStop(lots, symbol, price, 0, slPrice, tpPrice, "", expiration);
        }

      if(!result)
        {
         Print("TradeExec::PendingStopOrder -> failed, retcode=",
               trade.ResultRetcode(), " desc=", trade.ResultRetcodeDescription());
         return(false);
        }

      Print("TradeExec::PendingStopOrder -> success: ",
            (dir == DIR_BUY ? "BUY STOP " : "SELL STOP "), lots, " ", symbol,
            " at ", DoubleToString(price, _Digits),
            " SL=", DoubleToString(slPrice, _Digits),
            " TP=", DoubleToString(tpPrice, _Digits));
      return(true);
     }
  }

#endif // __TRADE_EXEC_MQH__

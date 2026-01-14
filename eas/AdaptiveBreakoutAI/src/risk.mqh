//+------------------------------------------------------------------+
//| risk.mqh - Risk management helpers for AdaptiveBreakoutAI        |
//+------------------------------------------------------------------+
#ifndef __RISK_MQH__
#define __RISK_MQH__

namespace Risk
  {
   // Generic lot sizing by risk% and SL distance in points
   double CalcLotsByRisk(string symbol, double slPoints, double riskPercent)
     {
      if(riskPercent <= 0.0 || slPoints <= 0.0)
        {
         Print("Risk::CalcLotsByRisk -> invalid params");
         return(0.0);
        }

      double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskMoney = balance * riskPercent / 100.0;
      double tickVal   = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

      if(tickVal <= 0.0 || tickSize <= 0.0)
        {
         Print("Risk::CalcLotsByRisk -> invalid tick parameters");
         return(0.0);
        }

      double pricePerPoint = tickVal / tickSize;
      double lossPerLot    = pricePerPoint * slPoints;
      if(lossPerLot <= 0.0)
         return(0.0);

      double lots = riskMoney / lossPerLot;

      double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

      if(lots < minLot) lots = minLot;
      if(lots > maxLot) lots = maxLot;

      double steps = MathFloor((lots - minLot) / stepLot + 0.5);
      lots = minLot + steps * stepLot;

      return(lots);
     }

   bool HasOpenPosition(string symbol)
     {
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(PositionSelectByTicket(ticket) &&
            PositionGetString(POSITION_SYMBOL) == symbol)
            return(true);
        }
      return(false);
     }

   int CountSymbolPositions(string symbol)
     {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(PositionSelectByTicket(ticket) &&
            PositionGetString(POSITION_SYMBOL) == symbol)
            count++;
        }
      return(count);
     }
  }

#endif // __RISK_MQH__

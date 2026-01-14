//+------------------------------------------------------------------+
//| volatility.mqh - ATR helper                                      |
//+------------------------------------------------------------------+
#ifndef __VOLATILITY_MQH__
#define __VOLATILITY_MQH__

namespace Volatility
  {
   double ATR(string symbol, ENUM_TIMEFRAMES tf, int period)
     {
      if(period <= 0)
        {
         Print("Volatility::ATR -> invalid period: ", period);
         return(0.0);
        }

      int handle = iATR(symbol, tf, period);
      if(handle == INVALID_HANDLE)
        {
         Print("Volatility::ATR -> invalid handle");
         return(0.0);
        }

      double buf[];
      if(CopyBuffer(handle, 0, 0, 1, buf) != 1)
        {
         Print("Volatility::ATR -> CopyBuffer failed");
         return(0.0);
        }

      return(buf[0]);
     }
  }

#endif // __VOLATILITY_MQH__

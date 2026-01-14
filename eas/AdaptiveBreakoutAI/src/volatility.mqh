//+------------------------------------------------------------------+
//| volatility.mqh - Volatility utilities (ATR, etc.)                |
//| For AdaptiveBreakoutAI                                           |
//+------------------------------------------------------------------+
#ifndef __VOLATILITY_MQH__
#define __VOLATILITY_MQH__

namespace Volatility
  {
   //--- Simple ATR wrapper
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
         Print("Volatility::ATR -> failed to create iATR handle for ", symbol);
         return(0.0);
        }

      double atrArr[];
      if(CopyBuffer(handle, 0, 0, 1, atrArr) != 1)
        {
         Print("Volatility::ATR -> CopyBuffer failed for ", symbol);
         return(0.0);
        }

      double atr = atrArr[0];
      // Optional: log rarely to avoid spam
      // Print("Volatility::ATR(", symbol, ") = ", DoubleToString(atr, _Digits));
      return(atr);
     }
  }

#endif // __VOLATILITY_MQH__

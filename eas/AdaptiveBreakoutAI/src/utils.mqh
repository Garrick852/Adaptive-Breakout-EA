//+------------------------------------------------------------------+
//| utils.mqh - Placeholder include for AdaptiveBreakoutAI EA        |
//| Provides utility/helper functions                                |
//+------------------------------------------------------------------+

#ifndef __UTILS_MQH__
#define __UTILS_MQH__

//--- Placeholder function for logging
void LogMessage(string msg)
  {
   Print("Utils::LogMessage placeholder -> ", msg);
  }

//--- Placeholder function for rounding values
double RoundToPips(double value, int pips)
  {
   double factor = MathPow(10, pips);
   double rounded = MathRound(value * factor) / factor;
   Print("Utils::RoundToPips placeholder -> ", rounded);
   return rounded;
  }

//--- Placeholder function for timestamp
string CurrentTimestamp()
  {
   datetime now = TimeCurrent();
   string ts = TimeToString(now, TIME_DATE|TIME_SECONDS);
   Print("Utils::CurrentTimestamp placeholder -> ", ts);
   return ts;
  }

#endif // __UTILS_MQH__

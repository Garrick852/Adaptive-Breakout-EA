//+------------------------------------------------------------------+
//| utils.mqh - Utility/helper functions for AdaptiveBreakoutAI      |
//+------------------------------------------------------------------+
#ifndef __UTILS_MQH__
#define __UTILS_MQH__

namespace Utils
  {
   void LogMessage(string msg)
     {
      Print("Utils::LogMessage -> ", msg);
     }

   string CurrentTimestamp()
     {
      datetime now = TimeCurrent();
      return(TimeToString(now, TIME_DATE|TIME_SECONDS));
     }

   bool IsWithinSession(int startHour, int endHour)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int h = dt.hour;

      if(startHour == endHour)
         return(true);

      if(startHour < endHour)
         return(h >= startHour && h < endHour);

      // wrap
      return(h >= startHour || h < endHour);
     }

   bool PassedCooldownMinutes(int minutes)
     {
      static datetime lastTradeTime = 0;

      if(minutes <= 0)
         return(true);

      datetime now = TimeCurrent();
      if(lastTradeTime == 0)
         return(true);

      int diffMin = (int)((now - lastTradeTime) / 60);
      return(diffMin >= minutes);
     }

   void StampTradeTime()
     {
      static datetime lastTradeTime = 0;
      lastTradeTime = TimeCurrent();
      Print("Utils::StampTradeTime -> lastTradeTime updated to ",
            TimeToString(lastTradeTime, TIME_DATE|TIME_SECONDS));
     }

   int ReadAISignal(string filename)
     {
      int handle = FileOpen(filename, FILE_READ|FILE_TXT|FILE_ANSI);
      if(handle == INVALID_HANDLE)
         return(0);

      string line = FileReadString(handle);
      FileClose(handle);

      line = StringTrim(line);
      if(line == "")
         return(0);

      int val = (int)StringToInteger(line);
      if(val > 1)  val = 1;
      if(val < -1) val = -1;
      return(val);
     }
  }

#endif // __UTILS_MQH__

//+------------------------------------------------------------------+
//| utils.mqh - Utility/helper functions for AdaptiveBreakoutAI      |
//+------------------------------------------------------------------+
#ifndef __UTILS_MQH__
#define __UTILS_MQH__

namespace Utils
  {
   //--- Basic logging
   void LogMessage(string msg)
     {
      Print("Utils::LogMessage -> ", msg);
     }

   //--- Timestamp
   string CurrentTimestamp()
     {
      datetime now = TimeCurrent();
      return(TimeToString(now, TIME_DATE|TIME_SECONDS));
     }

   //--- Session filter: true if current server hour in [startHour, endHour]
   bool IsWithinSession(int startHour, int endHour)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int h = dt.hour;

      if(startHour == endHour)
         return(true); // disabled / full-day

      if(startHour < endHour)
         return(h >= startHour && h < endHour);

      // wrap (e.g. 22 -> 6)
      return(h >= startHour || h < endHour);
     }

   //--- Simple cooldown using static last-trade time
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

   //--- Called by EA when it actually trades
   void StampTradeTime()
     {
      static datetime lastTradeTime = 0;
      lastTradeTime = TimeCurrent();
      Print("Utils::StampTradeTime -> lastTradeTime updated to ",
            TimeToString(lastTradeTime, TIME_DATE|TIME_SECONDS));
     }

   //--- Read AI signal (-1,0,+1) from a file in terminal "Files" directory
   int ReadAISignal(string filename)
     {
      int handle = FileOpen(filename, FILE_READ|FILE_TXT|FILE_ANSI);
      if(handle == INVALID_HANDLE)
        {
         // no file -> neutral
         // Print("Utils::ReadAISignal -> cannot open file, returning 0");
         return(0);
        }

      string line = FileReadString(handle);
      FileClose(handle);

      int val = (int)StringToInteger(StringTrim(line));
      if(val > 1)  val = 1;
      if(val < -1) val = -1;
      return(val);
     }
  }

#endif // __UTILS_MQH__

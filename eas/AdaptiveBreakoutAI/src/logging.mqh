// In utils.mqh (or logging.mqh)
namespace Logger
  {
   int logHandle = INVALID_HANDLE;

   void Init()
     {
      if(logHandle != INVALID_HANDLE)
         return;

      // FILE_SHARE_WRITE so the dashboard can read it while EA writes
      logHandle = FileOpen("adaptive_breakout_ea.log",
                           FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_WRITE|FILE_READ);
      if(logHandle != INVALID_HANDLE)
        {
         // Append mode: move pointer to end
         FileSeek(logHandle, 0, SEEK_END);
        }
      else
        {
         Print("Logger::Init -> failed to open adaptive_breakout_ea.log");
        }
     }

   void Close()
     {
      if(logHandle != INVALID_HANDLE)
        {
         FileClose(logHandle);
         logHandle = INVALID_HANDLE;
        }
     }

   void Log(const string msg)
     {
      if(logHandle == INVALID_HANDLE)
         Init();
      if(logHandle == INVALID_HANDLE)
         return;

      string line = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + " " + msg;
      FileWriteString(logHandle, line + "\n");
      FileFlush(logHandle);
     }
  }

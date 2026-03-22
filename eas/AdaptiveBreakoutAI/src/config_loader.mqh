//+------------------------------------------------------------------+
//| config_loader.mqh - Tiny flat-config loader for the EA           |
//| Reads key=value pairs from a text file in the Files directory    |
//+------------------------------------------------------------------+
#ifndef __CONFIG_LOADER_MQH__
#define __CONFIG_LOADER_MQH__

#include "utils.mqh"

// NOTE: BoxModeInput enum is declared in AdaptiveBreakoutAI.mq5.
// This file uses int for box-mode parameters to avoid duplicate declarations.

namespace ConfigLoader
  {
   // Internal trim helper: MQL5 lacks StringTrim(), so we use StringTrimLeft/Right
   // which modify strings in-place (unlike C-style return-value functions)
   string Trim(string s)
     {
      StringTrimLeft(s);
      StringTrimRight(s);
      return(s);
     }

   // Simple helpers to parse basic types ----------------------------
   bool ParseBool(string s, bool &out)
     {
      string t = s;
      StringToLower(t);
      StringTrimLeft(t);
      StringTrimRight(t);
      if(t == "true" || t == "1")
      s = Trim(s);
      StringToLower(s);
      if(s == "true" || s == "1")
        {
         out = true;
         return(true);
        }
      if(s == "false" || s == "0")
        {
         out = false;
         return(true);
        }
      return(false);
     }

   bool ParseDouble(string s, double &out)
     {
      string t = s;
      StringTrimLeft(t);
      StringTrimRight(t);
      out = StringToDouble(t);
      s = Trim(s);
      out = StringToDouble(s);
      // StringToDouble always returns a number; you can add extra checks if needed
      return(true);
     }

   bool ParseInt(string s, int &out)
     {
      string t = s;
      StringTrimLeft(t);
      StringTrimRight(t);
      out = (int)StringToInteger(t);
      return(true);
     }

   // Returns 0 for DONCHIAN, 1 for TIMERANGE, -1 on failure
   int ParseBoxMode(const string s)
     {
      string t = s;
      StringToUpper(t);
      StringTrimLeft(t);
      StringTrimRight(t);
      if(t == "DONCHIAN")  return(0);
      if(t == "TIMERANGE") return(1);
      return(-1);
      s = Trim(s);
      out = (int)StringToInteger(s);
      return(true);
     }

   bool ParseBoxMode(string s, int &out)
     {
      s = Trim(s);
      StringToUpper(s);
      if(s == "DONCHIAN")
        {
         out = 0; // BOXMODE_DONCHIAN (matches BoxModeInput enum in AdaptiveBreakoutAI.mq5)
         return(true);
        }
      if(s == "TIMERANGE")
        {
         out = 1; // BOXMODE_TIMERANGE (matches BoxModeInput enum in AdaptiveBreakoutAI.mq5)
         return(true);
        }
      return(false);
     }

   // Applies a single key/value to EA parameters --------------------
   void ApplyKV(string key,
                string value,
                // references to EA inputs
                int    &atr_period,
                double &atr_mult_sl,
                double &atr_mult_tp,
                double &min_atr_filter,
                int    &box_mode,
                int    &box_lookback_bars,
                int    &time_from_hour,
                int    &time_to_hour,
                double &breakout_buffer_pts,
                bool   &require_close_beyond,
                double &risk_percent_per_trade,
                bool   &use_pending_orders,
                bool   &use_atr_trail,
                double &atr_trail_mult)
     {
      // Match on known keys; ignore unknown keys
      if(key == "atr_period")
        {
         ParseInt(value, atr_period);
        }
      else if(key == "atr_mult_sl")
        {
         ParseDouble(value, atr_mult_sl);
        }
      else if(key == "atr_mult_tp")
        {
         ParseDouble(value, atr_mult_tp);
        }
      else if(key == "min_atr_filter")
        {
         ParseDouble(value, min_atr_filter);
        }
      else if(key == "box_mode")
        {
         int tmp = ParseBoxMode(value);
         if(tmp >= 0)
         int tmp;
         if(ParseBoxMode(value, tmp))
            box_mode = tmp;
        }
      else if(key == "box_lookback_bars")
        {
         ParseInt(value, box_lookback_bars);
        }
      else if(key == "time_from_hour")
        {
         ParseInt(value, time_from_hour);
        }
      else if(key == "time_to_hour")
        {
         ParseInt(value, time_to_hour);
        }
      else if(key == "breakout_buffer_pts")
        {
         ParseDouble(value, breakout_buffer_pts);
        }
      else if(key == "require_close_beyond")
        {
         bool b;
         if(ParseBool(value, b))
            require_close_beyond = b;
        }
      else if(key == "risk_percent_per_trade")
        {
         ParseDouble(value, risk_percent_per_trade);
        }
      else if(key == "use_pending_orders")
        {
         bool b;
         if(ParseBool(value, b))
            use_pending_orders = b;
        }
      else if(key == "use_atr_trail")
        {
         bool b;
         if(ParseBool(value, b))
            use_atr_trail = b;
        }
      else if(key == "atr_trail_mult")
        {
         ParseDouble(value, atr_trail_mult);
        }
      else
        {
         // Unknown key -> ignore silently
        }
     }

   // Main loader: returns true if file was read (even if partially) --
   bool LoadEAConfig(string filename,
                     // references to EA inputs
                     int    &atr_period,
                     double &atr_mult_sl,
                     double &atr_mult_tp,
                     double &min_atr_filter,
                     int    &box_mode,
                     int    &box_lookback_bars,
                     int    &time_from_hour,
                     int    &time_to_hour,
                     double &breakout_buffer_pts,
                     bool   &require_close_beyond,
                     double &risk_percent_per_trade,
                     bool   &use_pending_orders,
                     bool   &use_atr_trail,
                     double &atr_trail_mult)
     {
      int handle = FileOpen(filename, FILE_READ|FILE_TXT|FILE_ANSI);
      if(handle == INVALID_HANDLE)
        {
         Utils::LogMessage("ConfigLoader::LoadEAConfig -> cannot open file: " + filename);
         return(false);
        }

      while(!FileIsEnding(handle))
        {
         string line = FileReadString(handle);
         StringTrimLeft(line);
         StringTrimRight(line);
         line = Trim(line);

         if(line == "" || StringSubstr(line, 0, 1) == "#")
            continue;

         int eqPos = StringFind(line, "=");
         if(eqPos <= 0)
            continue;

         string key   = StringSubstr(line, 0, eqPos);
         string value = StringSubstr(line, eqPos + 1);
         StringTrimLeft(key);
         StringTrimRight(key);
         StringTrimLeft(value);
         StringTrimRight(value);
         string key   = Trim(StringSubstr(line, 0, eqPos));
         string value = Trim(StringSubstr(line, eqPos + 1));

         ApplyKV(key, value,
                 atr_period,
                 atr_mult_sl,
                 atr_mult_tp,
                 min_atr_filter,
                 box_mode,
                 box_lookback_bars,
                 time_from_hour,
                 time_to_hour,
                 breakout_buffer_pts,
                 require_close_beyond,
                 risk_percent_per_trade,
                 use_pending_orders,
                 use_atr_trail,
                 atr_trail_mult);
        }

      FileClose(handle);
      Utils::LogMessage("ConfigLoader::LoadEAConfig -> loaded file: " + filename);
      return(true);
     }
  }

#endif // __CONFIG_LOADER_MQH__


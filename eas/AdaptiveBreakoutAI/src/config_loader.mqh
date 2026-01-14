//+------------------------------------------------------------------+
//| config_loader.mqh - Tiny flat-config loader for the EA           |
//| Reads key=value pairs from a text file in the Files directory    |
//+------------------------------------------------------------------+
#ifndef __CONFIG_LOADER_MQH__
#define __CONFIG_LOADER_MQH__

#include "utils.mqh"

// Forward declare BoxModeInput from the EA
enum BoxModeInput
  {
   BOXMODE_DONCHIAN  = 0,
   BOXMODE_TIMERANGE = 1
  };

namespace ConfigLoader
  {
   // Simple helpers to parse basic types ----------------------------
   bool ParseBool(const string s, bool &out)
     {
      string t = StringTrim(StringToLower(s));
      if(t == "true" || t == "1")
        {
         out = true;
         return(true);
        }
      if(t == "false" || t == "0")
        {
         out = false;
         return(true);
        }
      return(false);
     }

   bool ParseDouble(const string s, double &out)
     {
      string t = StringTrim(s);
      out = StringToDouble(t);
      // StringToDouble always returns a number; you can add extra checks if needed
      return(true);
     }

   bool ParseInt(const string s, int &out)
     {
      string t = StringTrim(s);
      out = (int)StringToInteger(t);
      return(true);
     }

   bool ParseBoxMode(const string s, BoxModeInput &out)
     {
      string t = StringTrim(StringToUpper(s));
      if(t == "DONCHIAN")
        {
         out = BOXMODE_DONCHIAN;
         return(true);
        }
      if(t == "TIMERANGE")
        {
         out = BOXMODE_TIMERANGE;
         return(true);
        }
      return(false);
     }

   // Applies a single key/value to EA parameters --------------------
   void ApplyKV(const string key,
                const string value,
                // references to EA inputs
                int    &atr_period,
                double &atr_mult_sl,
                double &atr_mult_tp,
                double &min_atr_filter,
                BoxModeInput &box_mode,
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
         BoxModeInput tmp;
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
         // Unknown key -> ignore or optionally log
         // Utils::LogMessage("ConfigLoader: unknown key '" + key + "'");
        }
     }

   // Main loader: returns true if file was read (even if partially) --
   bool LoadEAConfig(string filename,
                     // references to EA inputs
                     int    &atr_period,
                     double &atr_mult_sl,
                     double &atr_mult_tp,
                     double &min_atr_filter,
                     BoxModeInput &box_mode,
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
         line = StringTrim(line);

         if(line == "" || StringSubstr(line, 0, 1) == "#")
            continue;

         int eqPos = StringFind(line, "=");
         if(eqPos <= 0)
            continue;

         string key   = StringTrim(StringSubstr(line, 0, eqPos));
         string value = StringTrim(StringSubstr(line, eqPos + 1));

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

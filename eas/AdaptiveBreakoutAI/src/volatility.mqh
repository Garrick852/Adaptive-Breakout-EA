// eas/AdaptiveBreakoutAI/src/volatility.mqh
#ifndef VOLATILITY_MQH
#define VOLATILITY_MQH

class Volatility
{
public:
    // --- ATR Calculation ---
    static double ATR(string symbol, ENUM_TIMEFRAMES timeframe, int period)
    {
        if (period <= 0) return 0.0;
        double atr_buffer[];
        int atr_handle = iATR(symbol, timeframe, period);
        if (atr_handle == INVALID_HANDLE) return 0.0;
        if (CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) > 0) {
            return atr_buffer[0];
        }
        return 0.0;
    }

    // --- Donchian Channel (Box) ---
    // CORRECTED: Removed the invalid 'out' keyword. The ampersand '&' is all that's needed.
    static bool Donchian(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift, double &high, double &low)
    {
        if (period <= 0) return false;

        double high_buffer[], low_buffer[];
        if (CopyHigh(symbol, timeframe, shift, period, high_buffer) < period || 
            CopyLow(symbol, timeframe, shift, period, low_buffer) < period) {
            return false;
        }

        // CORRECTED: ArrayMaximum/Minimum return an index, not the value.
        int high_index = ArrayMaximum(high_buffer);
        int low_index = ArrayMinimum(low_buffer);

        high = high_buffer[high_index];
        low = low_buffer[low_index];
        
        return true;
    }

    // --- Time-Range Box ---
    // CORRECTED: Removed the invalid 'out' keyword.
    static bool TimeRange(string symbol, ENUM_TIMEFRAMES timeframe, int from_hour, int to_hour, int shift, double &high, double &low)
    {
        MqlRates rates[];
        if (CopyRates(symbol, timeframe, shift, 500, rates) <= 0) return false;
        
        double range_high = 0;
        double range_low = 999999.0; // Initialize with a very large number
        bool found_bar_in_range = false;

        for (int i = ArraySize(rates) - 1; i >= 0; i--) {
            MqlDateTime time;
            TimeToStruct(rates[i].time, time);
            
            if (time.hour >= from_hour && time.hour < to_hour) {
                if (rates[i].high > range_high) range_high = rates[i].high;
                if (rates[i].low < range_low) range_low = rates[i].low;
                found_bar_in_range = true;
            }
        }
        
        if (!found_bar_in_range) return false;
        
        high = range_high;
        low = range_low;
        
        return true;
    }
};

#endif // VOLATILITY_MQH

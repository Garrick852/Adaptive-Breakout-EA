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
        
        if (CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) > 0)
        {
            return atr_buffer[0];
        }
        return 0.0;
    }

    // --- Donchian Channel ---
    static bool Donchian(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift, out double &high, out double &low)
    {
        if (period <= 0) return false;

        double high_buffer[], low_buffer[];
        if (CopyHigh(symbol, timeframe, shift, period, high_buffer) < period || 
            CopyLow(symbol, timeframe, shift, period, low_buffer) < period)
        {
            return false;
        }

        high = high_buffer[ArrayMaximum(high_buffer)];
        low = low_buffer[ArrayMinimum(low_buffer)];
        return true;
    }

    // --- Time-Range Box ---
    static bool TimeRange(string symbol, ENUM_TIMEFRAMES timeframe, int from_hour, int to_hour, int shift, out double &high, out double &low)
    {
        MqlRates rates[];
        // Copy enough bars to reliably find the time range
        if (CopyRates(symbol, timeframe, shift, 500, rates) <= 0) return false;
        
        double range_high = 0.0;
        double range_low = 999999.9; // Use a very large number for initialization
        bool found_bar_in_range = false;

        for (int i = ArraySize(rates) - 1; i >= 0; i--)
        {
            MqlDateTime time;
            TimeToStruct(rates[i].time, time);
            
            if (time.hour >= from_hour && time.hour < to_hour)
            {
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
}; // This semicolon is critical

#endif // VOLATILITY_MQH

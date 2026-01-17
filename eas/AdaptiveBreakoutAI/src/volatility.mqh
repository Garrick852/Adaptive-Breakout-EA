// eas/AdaptiveBreakoutAI/src/volatility.mqh
#ifndef VOLATILITY_MQH
#define VOLATILITY_MQH

class Volatility
{
public:
    // --- ATR Calculation ---
    static double ATR(string symbol, ENUM_TIMEFRAMES timeframe, int period)
    {
        double atr_buffer[];
        int atr_handle = iATR(symbol, timeframe, period);
        if (CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0) {
            return atr_buffer[0];
        }
        return 0.0;
    }

    // --- Donchian Channel ---
    static bool Donchian(string symbol, ENUM_TIMEFRAMES timeframe, int lookback, int shift, out double &high, out double &low)
    {
        double high_buffer[], low_buffer[];
        if (CopyHigh(symbol, timeframe, shift, lookback, high_buffer) < lookback ||
            CopyLow(symbol, timeframe, shift, lookback, low_buffer) < lookback) {
            return false;
        }
        high = high_buffer[ArrayMaximum(high_buffer)];
        low = low_buffer[ArrayMinimum(low_buffer)];
        return true;
    }

    // --- Time-Range Box ---
    static bool TimeRange(string symbol, ENUM_TIMEFRAMES timeframe, int startHour, int endHour, int shift, out double &high, out double &low)
    {
        // Placeholder for your time-range logic
        return false;
    }
}; // <-- FIX: THE MISSING SEMICOLON GOES HERE

#endif // VOLATILITY_MQH

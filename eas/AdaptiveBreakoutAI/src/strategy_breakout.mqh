// eas/AdaptiveBreakoutAI/src/strategy_breakout.mqh
#ifndef STRATEGY_BREAKOUT_MQH
#define STRATEGY_BREAKOUT_MQH

#include "trade_exec.mqh"
#include "volatility.mqh" // This include will now work correctly

class StrategyBreakout
{
public:
    enum BoxMode { BOXMODE_DONCHIAN = 0, BOXMODE_TIMERANGE = 1 };

    static bool Run(
        string symbol,
        BoxMode boxMode,
        int lookback,
        int timeFrom,
        int timeTo,
        double bufferPts,
        bool requireClose,
        double atr,
        double atrMultSL,
        double atrMultTP,
        double riskPct,
        bool usePending,
        double minAtrFilter
    ) {
        if (atr <= 0.0 || (minAtrFilter > 0 && atr < minAtrFilter)) return false;

        double boxHigh = 0.0, boxLow = 0.0;
        bool hasBox = (boxMode == BOXMODE_DONCHIAN)
            ? Volatility::Donchian(symbol, PERIOD_CURRENT, lookback, 0, boxHigh, boxLow)
            : Volatility::TimeRange(symbol, PERIOD_CURRENT, timeFrom, timeTo, 0, boxHigh, boxLow);
        
        if (!hasBox) return false;

        MqlRates rates[];
        if (CopyRates(symbol, PERIOD_CURRENT, 0, 1, rates) <= 0) return false;
        
        // ... rest of the function ...
        return true; // Placeholder
    }
};

#endif // STRATEGY_BREAKOUT_MQH

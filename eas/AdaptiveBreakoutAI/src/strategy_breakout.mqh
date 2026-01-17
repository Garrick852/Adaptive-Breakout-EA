// eas/AdaptiveBreakoutAI/src/strategy_breakout.mqh

#ifndef STRATEGY_BREAKOUT_MQH
#define STRATEGY_BREAKOUT_MQH

// No using statements
#include "trade_exec.mqh"
#include "volatility.mqh"

class StrategyBreakout {
public:
    enum BoxMode {
        BOXMODE_DONCHIAN  = 0,
        BOXMODE_TIMERANGE = 1
    };

    // The rest of your StrategyBreakout class code...
    // (The internal code for the Run method from my previous answer is correct)
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
        if (atr <= 0.0 || (minAtrFilter > 0 && atr < minAtrFilter)) {
            return false;
        }

        double boxHigh, boxLow;
        bool hasBox = (boxMode == BOXMODE_DONCHIAN)
            ? Volatility::Donchian(symbol, PERIOD_CURRENT, lookback, 0, boxHigh, boxLow)
            : Volatility::TimeRange(symbol, PERIOD_CURRENT, timeFrom, timeTo, 0, boxHigh, boxLow);

        if (!hasBox) {
            return false;
        }

        MqlRates rates[];
        if (CopyRates(symbol, PERIOD_CURRENT, 0, 1, rates) <= 0) {
            return false;
        }
        double currentClose = rates[0].close;

        TradeExec::Direction dir = TradeExec::DIR_NONE;
        double entryPrice = 0;

        if ((requireClose && currentClose > boxHigh) || (!requireClose && Ask > boxHigh)) {
            dir = TradeExec::DIR_BUY;
            entryPrice = boxHigh + (bufferPts * _Point);
        } else if ((requireClose && currentClose < boxLow) || (!requireClose && Bid < boxLow)) {
            dir = TradeExec::DIR_SELL;
            entryPrice = boxLow - (bufferPts * _Point);
        }

        if (dir == TradeExec::DIR_NONE) {
            return false;
        }
        
        double sl = atr * atrMultSL;
        double tp = atr * atrMultTP;
        
        if (usePending) {
            return TradeExec::PendingStopOrder(symbol, dir, entryPrice, sl, tp, riskPct, 0);
        } else {
            return TradeExec::MarketOrder(symbol, dir, sl, tp, riskPct);
        }
        return true;
    }
};

#endif // STRATEGY_BREAKOUT_MQH

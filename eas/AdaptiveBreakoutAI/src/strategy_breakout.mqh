// Include/AdaptiveBreakoutAI/strategy_breakout.mqh
#pragma once

#include <Trade\Trade.mqh> // Standard library for trade execution
#include "volatility.mqh"   // For the Box class
#include "trade_exec.mqh"   // For TradeExec class

class StrategyBreakout {
public:
    enum BoxMode {
        BOXMODE_DONCHIAN  = 0,
        BOXMODE_TIMERANGE = 1
    };

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

        // Determine trade direction
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
        
        // Calculate SL and TP
        double sl = atr * atrMultSL;
        double tp = atr * atrMultTP;
        
        // Execute trade
        if (usePending) {
            return TradeExec::PendingStopOrder(symbol, dir, entryPrice, sl, tp, riskPct, 0);
        } else {
            return TradeExec::MarketOrder(symbol, dir, sl, tp, riskPct);
        }
        return true;
    }
};

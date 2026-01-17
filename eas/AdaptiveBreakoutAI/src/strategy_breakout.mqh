// CORRECTED
#pragma once

#include "volatility.mqh"
#include "trade_exec.mqh"

class StrategyBreakout 
{
public:
    enum BoxMode 
    {
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
        double minAtrFilter)
    {
        if (atr <= 0.0 || (minAtrFilter > 0 && atr < minAtrFilter))
            return false;

        double boxHigh, boxLow;
        bool hasBox = (boxMode == BOXMODE_DONCHIAN)
            ? Volatility::Donchian(symbol, PERIOD_CURRENT, lookback, 0, boxHigh, boxLow)
            : Volatility::TimeRange(symbol, PERIOD_CURRENT, timeFrom, timeTo, 0, boxHigh, boxLow);

        if (!hasBox)
            return false;

        MqlRates rates[];
        if (CopyRates(symbol, PERIOD_CURRENT, 0, 1, rates) <= 0)
            return false;
        double currentClose = rates[0].close;
        
        TradeExec::Direction dir = TradeExec::DIR_NONE;
        double entryPrice = 0;

        if ((requireClose && currentClose > boxHigh + (bufferPts * _Point)) || (!requireClose && Ask > boxHigh + (bufferPts * _Point))) {
            dir = TradeExec::DIR_BUY;
            entryPrice = Ask; // Market order price
        } else if ((requireClose && currentClose < boxLow - (bufferPts * _Point)) || (!requireClose && Bid < boxLow - (bufferPts * _Point))) {
            dir = TradeExec::DIR_SELL;
            entryPrice = Bid; // Market order price
        }

        if (dir == TradeExec::DIR_NONE)
            return false;

        double sl = atr * atrMultSL;
        double tp = atr * atrMultTP;

        if (usePending) {
            double pendingPrice = (dir == TradeExec::DIR_BUY) ? boxHigh + (bufferPts * _Point) : boxLow - (bufferPts * _Point);
            return TradeExec::PendingStopOrder(symbol, dir, pendingPrice, sl, tp, riskPct, 0);
        } else {
            return TradeExec::MarketOrder(symbol, dir, sl, tp, riskPct);
        }
    }
};

// CORRECTED
#ifndef STRATEGY_BREAKOUT_MQH
#define STRATEGY_BREAKOUT_MQH

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
        // --- THIS IS A FIX ---
        // Pass the correct parameters to the Volatility functions
        bool hasBox = (boxMode == BOXMODE_DONCHIAN)
            ? Volatility::Donchian(symbol, PERIOD_CURRENT, lookback, 0, boxHigh, boxLow)
            : Volatility::TimeRange(symbol, PERIOD_CURRENT, timeFrom, timeTo, 0, boxHigh, boxLow);

        if (!hasBox)
            return false;

        MqlRates rates[];
        // --- THIS IS A FIX ---
        // Pass the correct ENUM_TIMEFRAMES parameter
        if (CopyRates(symbol, (ENUM_TIMEFRAMES)PERIOD_CURRENT, 0, 1, rates) <= 0)
            return false;
        double currentClose = rates[0].close;
        
        TradeExec::Direction dir = TradeExec::DIR_NONE;
        double entryPrice = 0;
        double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(symbol, SYMBOL_BID);

        if ((requireClose && currentClose > boxHigh + (bufferPts * _Point)) || (!requireClose && ask > boxHigh + (bufferPts * _Point))) {
            dir = TradeExec::DIR_BUY;
        } else if ((requireClose && currentClose < boxLow - (bufferPts * _Point)) || (!requireClose && bid < boxLow - (bufferPts * _Point))) {
            dir = TradeExec::DIR_SELL;
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

#endif

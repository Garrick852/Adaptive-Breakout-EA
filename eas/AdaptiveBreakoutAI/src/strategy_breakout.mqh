// eas/AdaptiveBreakoutAI/src/strategy_breakout.mqh
#ifndef STRATEGY_BREAKOUT_MQH
#define STRATEGY_BREAKOUT_MQH

#include "trade_exec.mqh"
#include "volatility.mqh" // This will now work correctly

class StrategyBreakout 
{
public:
    enum BoxMode { BOX_DONCHIAN = 0, BOX_TIMERANGE = 1 };

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
        double minAtrFilter,
        TradeExec::Direction allowedDir = TradeExec::DIR_ANY   // MI-003: AOS direction gate
    ) {
        if (atr <= 0.0 || (minAtrFilter > 0 && atr < minAtrFilter)) return false;

        double boxHigh = 0.0, boxLow = 0.0;
        bool hasBox;

        // The requireClose signal bar is close[1]; the box must EXCLUDE bar 1
        // (shift=2 => bars 2..lookback+1), otherwise close[1] is always inside the
        // box (boxHigh includes bar 1's own high). The intrabar path compares the
        // forming bar 0 ask/bid, so shift=1 (bars 1..lookback) stays correct there.
        int boxShift = requireClose ? 2 : 1;

        if (boxMode == BOX_DONCHIAN) {
            hasBox = Volatility::Donchian(symbol, PERIOD_CURRENT, lookback, boxShift, boxHigh, boxLow);
        } else {
            hasBox = Volatility::TimeRange(symbol, PERIOD_CURRENT, timeFrom, timeTo, boxShift, boxHigh, boxLow);
        }
        
        if (!hasBox) return false;

        MqlRates rates[];
        if (CopyRates(symbol, PERIOD_CURRENT, 1, 1, rates) <= 0) return false;
        
        double currentClose = rates[0].close;
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
        
        TradeExec::Direction dir = TradeExec::DIR_NONE;
        double entryPrice = 0;

        if ((requireClose && currentClose > boxHigh) || (!requireClose && ask > boxHigh)) {
            dir = TradeExec::DIR_BUY;
            entryPrice = boxHigh + (bufferPts * point);
        } else if ((requireClose && currentClose < boxLow) || (!requireClose && bid < boxLow)) {
            dir = TradeExec::DIR_SELL;
            entryPrice = boxLow - (bufferPts * point);
        }

        if (dir == TradeExec::DIR_NONE) return false;

        // MI-003: AOS direction veto — local intent must match the AOS cmd.
        if (allowedDir != TradeExec::DIR_ANY && dir != allowedDir) return false;

        double sl = atr * atrMultSL;
        double tp = atr * atrMultTP;

        if (usePending) {
            return TradeExec::PendingStopOrder(symbol, dir, entryPrice, sl, tp, riskPct, 0);
        } else {
            return TradeExec::MarketOrder(symbol, dir, sl, tp, riskPct);
        }
    }
};

#endif // STRATEGY_BREAKOUT_MQH

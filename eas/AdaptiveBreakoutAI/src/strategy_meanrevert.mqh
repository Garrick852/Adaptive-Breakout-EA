// Include/AdaptiveBreakoutAI/strategy_meanrevert.mqh
#pragma once

#include <Trade\Trade.mqh>
#include "trade_exec.mqh"

class StrategyMeanRevert {
public:
    static bool Run(
        string symbol,
        int emaPeriod,
        double zScoreThresh,
        double atr,
        double atrMultSL,
        double atrMultTP,
        double riskPct
    ) {
        if (atr <= 0.0) return false;

        // Get EMA value
        double ema[];
        if (CopyBuffer(iMA(symbol, PERIOD_CURRENT, emaPeriod, 0, MODE_EMA, PRICE_CLOSE), 0, 0, 1, ema) <= 0) {
            return false;
        }
        double emaValue = ema[0];

        // Get current price
        MqlRates rates[];
        if (CopyRates(symbol, PERIOD_CURRENT, 0, 1, rates) <= 0) return false;
        double currentClose = rates[0].close;

        // Calculate Z-Score
        double zScore = (currentClose - emaValue) / atr;

        // Determine Direction
        TradeExec::Direction dir = TradeExec::DIR_NONE;
        if (zScore < -zScoreThresh) {
            dir = TradeExec::DIR_BUY;
        } else if (zScore > zScoreThresh) {
            dir = TradeExec::DIR_SELL;
        }

        if (dir == TradeExec::DIR_NONE) {
            return false;
        }

        // Calculate SL and TP
        double sl = atr * atrMultSL;
        double tp = atr * atrMultTP;

        // Execute Market Order
        return TradeExec::MarketOrder(symbol, dir, sl, tp, riskPct);
    }
};

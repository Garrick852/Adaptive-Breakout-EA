// eas/AdaptiveBreakoutAI/src/strategy_meanrevert.mqh

#ifndef STRATEGY_MEANREVERT_MQH
#define STRATEGY_MEANREVERT_MQH

// No using statements
#include "trade_exec.mqh"

class StrategyMeanRevert {
public:
    // The rest of your StrategyMeanRevert class code...
    // (The internal code for the Run method from my previous answer is correct)
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

        double ema[];
        if (CopyBuffer(iMA(symbol, PERIOD_CURRENT, emaPeriod, 0, MODE_EMA, PRICE_CLOSE), 0, 0, 1, ema) <= 0) {
            return false;
        }
        double emaValue = ema[0];

        MqlRates rates[];
        if (CopyRates(symbol, PERIOD_CURRENT, 0, 1, rates) <= 0) return false;
        double currentClose = rates[0].close;

        double zScore = (currentClose - emaValue) / atr;

        TradeExec::Direction dir = TradeExec::DIR_NONE;
        if (zScore < -zScoreThresh) {
            dir = TradeExec::DIR_BUY;
        } else if (zScore > zScoreThresh) {
            dir = TradeExec::DIR_SELL;
        }

        if (dir == TradeExec::DIR_NONE) {
            return false;
        }

        double sl = atr * atrMultSL;
        double tp = atr * atrMultTP;

        return TradeExec::MarketOrder(symbol, dir, sl, tp, riskPct);
    }
};

#endif // STRATEGY_MEANREVERT_MQH
